from main import app

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5319,  # Using your production port
        debug=False,  # Disable debug in production
        use_reloader=False,  # Disable reloader in production
        threaded=True
    ) 