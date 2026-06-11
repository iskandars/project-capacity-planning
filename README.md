<!-- # project-capacity-planning -->

# Project Capacity Planning System

A full-stack project management and capacity planning application that helps teams track project status, QA resources, test durations, and generate executive reports. Built with React, Node.js, Express, Redis, and Docker.

## Features

- **Project Management**: Create, read, update, delete projects with statuses (Backlog, In Development, Ready for Test, In Test, Ready for Release)
- **Dashboard & Analytics**: 
  - Pie chart for status distribution
  - Bar chart for test duration by project
  - Real-time metrics cards (total projects, QA resources, test days, FTE)
- **Filtering & Search**: 
  - Filter by project status
  - Search by assignee name
- **Google Sheets Integration**: Import project data from any public Google Sheets CSV URL
- **Reporting**: Export comprehensive PDF reports with analytics and executive summary
- **Metrics**: 
  - Total QA resources allocation
  - Estimated testing duration
  - FTE (person-days) calculation
  - Duration per project test
- **Redis Storage**: All data persisted in Redis for high performance

## Technology Stack

### Backend
- Node.js with Express
- Redis (ioredis)
- CSV parsing for Google Sheets imports
- UUID for unique identifiers

### Frontend
- React 18
- Vite for fast builds
- Tailwind CSS for styling
- Recharts for data visualization
- html2canvas + jsPDF for PDF export
- Axios for API calls
- Lucide React for icons

### Testing & DevOps
- Playwright for E2E frontend testing
- Postman for API testing collection
- Docker Compose for container orchestration
- PlantUML for sequence diagrams

## Prerequisites

- Docker and Docker Compose (v2+)
- Node.js 18+ (for local development)
- Redis (handled by Docker)

## Quick Start with Docker

1. Clone the repository:
```bash
git clone <repository-url>
cd capacity-planning
```

#### 2026@sisalehiskandar