// backend/server.js
const express = require('express');
const cors = require('cors');
const Redis = require('ioredis');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const csv = require('csv-parser');
const { Readable } = require('stream');

const app = express();
const PORT = process.env.PORT || 5000;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const redis = new Redis(REDIS_URL);

app.use(cors());
app.use(express.json());

// Redis key
const PROJECTS_KEY = 'projects';
const METRICS_KEY = 'project_metrics';

// Mock data generator
const generateMockProjects = () => {
  const statuses = ['backlog', 'in development', 'ready for test', 'in test', 'ready for release'];
  const assignees = ['Alice Chen', 'Bob Smith', 'Carol Davis', 'David Wilson', 'Eva Brown', 'Frank Miller'];
  const projects = [];
  
  const startDateBase = new Date('2024-01-01');
  
  for (let i = 1; i <= 15; i++) {
    const status = statuses[Math.floor(Math.random() * statuses.length)];
    const assignee = assignees[Math.floor(Math.random() * assignees.length)];
    const startDate = new Date(startDateBase);
    startDate.setDate(startDateBase.getDate() + (i * 7));
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + 30 + Math.floor(Math.random() * 30));
    
    projects.push({
      id: uuidv4(),
      name: `Project ${i}: ${['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'][i % 5]} ${['Core', 'Mobile', 'Web', 'API', 'Analytics'][i % 5]}`,
      status: status,
      assignee: assignee,
      startDate: startDate.toISOString().split('T')[0],
      endDate: endDate.toISOString().split('T')[0],
      testEstimateDays: Math.floor(Math.random() * 15) + 3, // 3-18 days
      qaResourceCount: Math.floor(Math.random() * 4) + 1, // 1-4 QA
      description: `Sample project for capacity planning`,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
  }
  return projects;
};

// Initialize Redis with mock data if empty
const initializeData = async () => {
  const exists = await redis.exists(PROJECTS_KEY);
  if (!exists) {
    const mockProjects = generateMockProjects();
    await redis.set(PROJECTS_KEY, JSON.stringify(mockProjects));
    console.log('Mock data seeded successfully');
  }
};

// Helper: get all projects
const getProjects = async () => {
  const data = await redis.get(PROJECTS_KEY);
  return data ? JSON.parse(data) : [];
};

// Helper: save projects
const saveProjects = async (projects) => {
  await redis.set(PROJECTS_KEY, JSON.stringify(projects));
};

// API Routes

// Get all projects with filters
app.get('/api/projects', async (req, res) => {
  try {
    let projects = await getProjects();
    const { status, assignee } = req.query;
    
    if (status) {
      const statuses = status.split(',');
      projects = projects.filter(p => statuses.includes(p.status));
    }
    
    if (assignee) {
      projects = projects.filter(p => 
        p.assignee.toLowerCase().includes(assignee.toLowerCase())
      );
    }
    
    res.json(projects);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get single project
app.get('/api/projects/:id', async (req, res) => {
  try {
    const projects = await getProjects();
    const project = projects.find(p => p.id === req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });
    res.json(project);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create project
app.post('/api/projects', async (req, res) => {
  try {
    const projects = await getProjects();
    const newProject = {
      id: uuidv4(),
      ...req.body,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    projects.push(newProject);
    await saveProjects(projects);
    res.status(201).json(newProject);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update project
app.put('/api/projects/:id', async (req, res) => {
  try {
    const projects = await getProjects();
    const index = projects.findIndex(p => p.id === req.params.id);
    if (index === -1) return res.status(404).json({ error: 'Project not found' });
    
    projects[index] = {
      ...projects[index],
      ...req.body,
      id: req.params.id,
      updatedAt: new Date().toISOString()
    };
    await saveProjects(projects);
    res.json(projects[index]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete project
app.delete('/api/projects/:id', async (req, res) => {
  try {
    let projects = await getProjects();
    const filtered = projects.filter(p => p.id !== req.params.id);
    if (filtered.length === projects.length) {
      return res.status(404).json({ error: 'Project not found' });
    }
    await saveProjects(filtered);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Upload from Google Sheets (via public CSV URL)
app.post('/api/upload-gsheet', async (req, res) => {
  try {
    const { sheetUrl } = req.body;
    if (!sheetUrl) {
      return res.status(400).json({ error: 'Sheet URL is required' });
    }
    
    // Fetch CSV from URL
    const response = await axios.get(sheetUrl, { responseType: 'text' });
    const csvData = response.data;
    
    // Parse CSV
    const results = [];
    const stream = Readable.from(csvData);
    
    await new Promise((resolve, reject) => {
      stream
        .pipe(csv())
        .on('data', (data) => results.push(data))
        .on('end', resolve)
        .on('error', reject);
    });
    
    // Transform CSV rows to project objects
    const newProjects = results.map(row => ({
      id: uuidv4(),
      name: row.name || row.project_name || 'Unnamed Project',
      status: row.status || 'backlog',
      assignee: row.assignee || 'Unassigned',
      startDate: row.startDate || row.start_date || new Date().toISOString().split('T')[0],
      endDate: row.endDate || row.end_date || new Date().toISOString().split('T')[0],
      testEstimateDays: parseInt(row.testEstimateDays || row.test_estimate_days || 5),
      qaResourceCount: parseInt(row.qaResourceCount || row.qa_resource_count || 1),
      description: row.description || '',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }));
    
    // Merge with existing projects (replace all for simplicity)
    await saveProjects(newProjects);
    res.json({ message: 'Data imported successfully', count: newProjects.length });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'Failed to process Google Sheet: ' + error.message });
  }
});

// Get statistics and metrics
app.get('/api/stats', async (req, res) => {
  try {
    const projects = await getProjects();
    
    // Status distribution
    const statusCount = {};
    projects.forEach(p => {
      statusCount[p.status] = (statusCount[p.status] || 0) + 1;
    });
    
    // Total metrics
    const totalProjects = projects.length;
    const totalQAResources = projects.reduce((sum, p) => sum + p.qaResourceCount, 0);
    const totalEstimatedTestDuration = projects.reduce((sum, p) => sum + p.testEstimateDays, 0);
    
    // FTE calculation (person-days effort)
    const totalFTE = projects.reduce((sum, p) => sum + (p.qaResourceCount * p.testEstimateDays), 0);
    
    // Assignee list for search
    const assignees = [...new Set(projects.map(p => p.assignee))];
    
    // Project test durations per project
    const projectDurations = projects.map(p => ({
      id: p.id,
      name: p.name,
      testDurationDays: p.testEstimateDays,
      status: p.status
    }));
    
    res.json({
      totalProjects,
      totalQAResources,
      totalEstimatedTestDuration,
      totalFTE,
      statusDistribution: statusCount,
      assignees,
      projectDurations,
      projects
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
const startServer = async () => {
  await initializeData();
  app.listen(PORT, () => {
    console.log(`Backend server running on port ${PORT}`);
  });
};

startServer().catch(console.error);
