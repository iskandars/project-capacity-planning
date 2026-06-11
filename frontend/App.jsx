// frontend/src/App.jsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, PieChart, Pie, Cell,
  LineChart, Line, ResponsiveContainer
} from 'recharts';
import { 
  Download, Search, Filter, Upload, RefreshCw, 
  Calendar, Users, Clock, Briefcase, AlertCircle,
  CheckCircle, PlayCircle, TestTube, Rocket, Inbox
} from 'lucide-react';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';

const API_URL = '/api';

const statusColors = {
  'backlog': '#94a3b8',
  'in development': '#3b82f6',
  'ready for test': '#eab308',
  'in test': '#8b5cf6',
  'ready for release': '#10b981'
};

const statusIcons = {
  'backlog': Inbox,
  'in development': PlayCircle,
  'ready for test': AlertCircle,
  'in test': TestTube,
  'ready for release': Rocket
};

function App() {
  const [projects, setProjects] = useState([]);
  const [filteredProjects, setFilteredProjects] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [assigneeSearch, setAssigneeSearch] = useState('');
  const [sheetUrl, setSheetUrl] = useState('');
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [uploading, setUploading] = useState(false);

  // Fetch data
  const fetchData = async () => {
    setLoading(true);
    try {
      const params = {};
      if (statusFilter) params.status = statusFilter;
      if (assigneeSearch) params.assignee = assigneeSearch;
      
      const [projectsRes, statsRes] = await Promise.all([
        axios.get(`${API_URL}/projects`, { params }),
        axios.get(`${API_URL}/stats`)
      ]);
      
      setProjects(projectsRes.data);
      setFilteredProjects(projectsRes.data);
      setStats(statsRes.data);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [statusFilter, assigneeSearch]);

  // Upload from Google Sheets
  const handleUploadFromSheet = async () => {
    if (!sheetUrl) {
      alert('Please enter a Google Sheets CSV URL');
      return;
    }
    setUploading(true);
    try {
      await axios.post(`${API_URL}/upload-gsheet`, { sheetUrl });
      alert('Data imported successfully!');
      setShowUploadModal(false);
      setSheetUrl('');
      fetchData();
    } catch (error) {
      alert('Error importing data: ' + error.response?.data?.error || error.message);
    } finally {
      setUploading(false);
    }
  };

  // Export to PDF
  const exportToPDF = async () => {
    const element = document.getElementById('report-content');
    if (!element) return;
    
    const canvas = await html2canvas(element, { scale: 2 });
    const imgData = canvas.toDataURL('image/png');
    const pdf = new jsPDF('p', 'mm', 'a4');
    const imgWidth = 210;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;
    
    pdf.addImage(imgData, 'PNG', 0, 0, imgWidth, imgHeight);
    pdf.save('capacity-planning-report.pdf');
  };

  // Prepare chart data
  const statusChartData = stats?.statusDistribution 
    ? Object.entries(stats.statusDistribution).map(([name, value]) => ({ name, value }))
    : [];
    
  const projectDurationsData = stats?.projectDurations?.slice(0, 10) || [];

  // Calculate summary metrics for filtered view
  const filteredMetrics = {
    totalProjects: filteredProjects.length,
    totalQA: filteredProjects.reduce((sum, p) => sum + p.qaResourceCount, 0),
    totalTestDays: filteredProjects.reduce((sum, p) => sum + p.testEstimateDays, 0),
    totalFTE: filteredProjects.reduce((sum, p) => sum + (p.qaResourceCount * p.testEstimateDays), 0)
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Project Capacity Planning</h1>
              <p className="text-gray-600 mt-1">Manage projects, track QA resources, and analyze team capacity</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowUploadModal(true)}
                className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
              >
                <Upload size={18} /> Import from Sheet
              </button>
              <button
                onClick={exportToPDF}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
              >
                <Download size={18} /> Export PDF
              </button>
              <button
                onClick={fetchData}
                className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
              >
                <RefreshCw size={18} /> Refresh
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        {/* Filters */}
        <div className="bg-white rounded-lg shadow p-6 mb-8">
          <div className="flex flex-wrap gap-4 items-end">
            <div className="flex-1 min-w-[200px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">Status Filter</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              >
                <option value="">All Statuses</option>
                <option value="backlog">Backlog</option>
                <option value="in development">In Development</option>
                <option value="ready for test">Ready for Test</option>
                <option value="in test">In Test</option>
                <option value="ready for release">Ready for Release</option>
              </select>
            </div>
            <div className="flex-1 min-w-[200px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">Search by Assignee</label>
              <div className="relative">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
                <input
                  type="text"
                  value={assigneeSearch}
                  onChange={(e) => setAssigneeSearch(e.target.value)}
                  placeholder="Enter assignee name..."
                  className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
            </div>
            <button
              onClick={() => { setStatusFilter(''); setAssigneeSearch(''); }}
              className="px-4 py-2 text-gray-600 hover:text-gray-900"
            >
              Clear Filters
            </button>
          </div>
        </div>

        {/* Metrics Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Total Projects</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalProjects}</p>
              </div>
              <Briefcase className="text-blue-500" size={32} />
            </div>
          </div>
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Total QA Resources</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalQA}</p>
              </div>
              <Users className="text-green-500" size={32} />
            </div>
          </div>
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Est. Test Duration (days)</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalTestDays}</p>
              </div>
              <Clock className="text-purple-500" size={32} />
            </div>
          </div>
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Total FTE (person-days)</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalFTE}</p>
              </div>
              <Calendar className="text-orange-500" size={32} />
            </div>
          </div>
        </div>

        {/* Charts Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8" id="report-content">
          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">Project Status Distribution</h3>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={statusChartData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                  outerRadius={100}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {statusChartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={statusColors[entry.name] || '#94a3b8'} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">Project Test Duration (Top 10)</h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={projectDurationsData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} tick={{ fontSize: 10 }} />
                <YAxis label={{ value: 'Days', angle: -90, position: 'insideLeft' }} />
                <Tooltip />
                <Bar dataKey="testDurationDays" fill="#8884d8" name="Test Duration (days)" />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Executive Summary */}
          <div className="lg:col-span-2 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-3">Executive Summary</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p className="text-gray-700"><strong>Capacity Overview:</strong> Currently managing {filteredMetrics.totalProjects} projects with {filteredMetrics.totalQA} QA resources allocated.</p>
                <p className="text-gray-700 mt-2"><strong>Test Effort:</strong> Estimated {filteredMetrics.totalTestDays} test days required across all projects.</p>
                <p className="text-gray-700 mt-2"><strong>FTE Analysis:</strong> Total effort of {filteredMetrics.totalFTE} person-days needed for testing activities.</p>
              </div>
              <div>
                <p className="text-gray-700"><strong>Status Insights:</strong> {statusChartData.map(s => `${s.name}: ${s.value}`).join(', ')}</p>
                <p className="text-gray-700 mt-2"><strong>Resource Efficiency:</strong> Average QA per project: {(filteredMetrics.totalQA / filteredMetrics.totalProjects || 0).toFixed(1)}</p>
                <p className="text-gray-700 mt-2"><strong>Recommendation:</strong> Prioritize projects in 'ready for test' status to optimize QA utilization.</p>
              </div>
            </div>
          </div>
        </div>

        {/* Projects Table */}
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <div className="px-6 py-4 border-b">
            <h3 className="text-lg font-semibold">Project List</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Project Name</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Assignee</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Start Date</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">End Date</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Test Duration (days)</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">QA Resources</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-8 text-center text-gray-500">Loading...</td>
                  </tr>
                ) : filteredProjects.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-8 text-center text-gray-500">No projects found</td>
                  </tr>
                ) : (
                  filteredProjects.map((project) => {
                    const StatusIcon = statusIcons[project.status] || CheckCircle;
                    return (
                      <tr key={project.id} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap font-medium">{project.name}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium`}
                            style={{ backgroundColor: `${statusColors[project.status]}20`, color: statusColors[project.status] }}>
                            <StatusIcon size={12} />
                            {project.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.assignee}</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.startDate}</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.endDate}</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.testEstimateDays} days</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.qaResourceCount}</td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </main>

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 className="text-xl font-semibold mb-4">Import from Google Sheets</h3>
            <p className="text-gray-600 mb-4 text-sm">
              Enter the CSV export URL from Google Sheets. To get this: Publish your sheet to the web (File → Share → Publish to web → Link → CSV).
            </p>
            <input
              type="text"
              value={sheetUrl}
              onChange={(e) => setSheetUrl(e.target.value)}
              placeholder="https://docs.google.com/spreadsheets/d/.../export?format=csv"
              className="w-full border border-gray-300 rounded-lg px-3 py-2 mb-4"
            />
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowUploadModal(false)}
                className="px-4 py-2 text-gray-600 hover:text-gray-900"
              >
                Cancel
              </button>
              <button
                onClick={handleUploadFromSheet}
                disabled={uploading}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
              >
                {uploading ? 'Importing...' : 'Import'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
