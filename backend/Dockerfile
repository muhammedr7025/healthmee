FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=wsgi.py

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=4).status == 200 else 1)"

# Threaded workers: requests that wait on an LLM, SMTP or S3 no longer pin a
# whole process, and the 60s timeout sits above the 20s LLM timeout so the
# offline fallback gets to run instead of the worker being killed.
CMD ["gunicorn", "-b", "0.0.0.0:5000", "-w", "2", "-k", "gthread", "--threads", "8", "--timeout", "60", "--access-logfile", "-", "wsgi:app"]
