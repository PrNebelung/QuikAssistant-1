from flask import Flask, render_template
from api import api
from moex_api import refresh_instruments, _load_cache, CACHE_TTL
import os
import time

app = Flask(__name__)
app.register_blueprint(api)

# Auto-refresh instrument cache on startup if stale
cache_file = os.path.join(os.path.dirname(__file__), "instruments_cache.json")
cache = _load_cache()
cache_age = time.time() - cache.get("updated", 0)
if not os.path.exists(cache_file) or cache_age > CACHE_TTL:
    print(
        f"Кэш отсутствует или устарел ({int(cache_age / 3600)}ч). Загрузка данных инструментов из MOEX..."
    )
    refresh_instruments()
    print("Готово.")


@app.route("/")
def index():
    return render_template("index.html")


if __name__ == "__main__":
    app.run(debug=True, port=5000)
