# UK Postcode Distance Calculator

A web application that tracks journeys between UK postcodes, automatically detects your location, and calculates distances.

## Features

- Automatic location detection using device geolocation
- Conversion of GPS coordinates to UK postcodes
- Journey tracking with start and end points
- Distance calculation in miles between postcodes
- Journey history with export to CSV or Excel
- Bulk selection and deletion of journey records

## Local Development Setup

### Prerequisites

- Python 3.11 or higher
- Flask and dependencies (see requirements below)
- Internet connection for postcode API access

### Installation

1. Clone the repository to your local machine:

```bash
git clone <repository-url>
cd <repository-directory>
```

2. Create and activate a virtual environment:

```bash
python -m venv venv
source venv/bin/activate  # On Windows, use: venv\Scripts\activate
```

3. Install the required packages:

```bash
pip install -r requirements-local.txt
```

4. Set up environment variables:

```bash
cp .env.example .env
# Edit .env with your desired settings
```

### Running the Application

1. If you're running the app for the first time or after pulling updates, run the database migration script:

```bash
python migrate.py
```

2. Run the Flask development server:

```bash
python main.py
```

This will start the application on http://localhost:5000.

### Database Configuration

By default, the application uses SQLite for local development. If you want to use PostgreSQL:

1. Set up a PostgreSQL database
2. Configure the DATABASE_URL in your .env file:

```
DATABASE_URL=postgresql://username:password@localhost:5432/dbname
```

## API Endpoints

- `/api/journey/start` - Start a new journey
- `/api/journey/end` - End an active journey
- `/api/journey/active` - Get the active journey
- `/api/journeys` - Get all completed journeys
- `/api/journeys/export/csv` - Export journeys as CSV
- `/api/journeys/export/excel` - Export journeys as Excel
- `/api/journeys/delete` - Delete selected journeys

## License

[MIT License](LICENSE)