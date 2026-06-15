from flask import Flask, render_template
from api import api
from moex_api import refresh_instruments
import os

app = Flask(__name__)
app.register_blueprint(api)

# Auto-refresh instrument cache on startup
cache_file = os.path.join(os.path.dirname(__file__), '..', 'Data', 'instruments_cache.json')
if not os.path.exists(cache_file):
    print("Loading instrument data from MOEX...")
    refresh_instruments()
    print("Done.")

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True, port=5000)
