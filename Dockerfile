FROM python:3.13-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# Runtime deps only (notebook/test tooling is left out of the image)
COPY requirements.txt .
RUN grep -vE '^(jupyter|nbconvert|ipykernel|pytest)' requirements.txt > req-runtime.txt \
 && pip install --no-cache-dir -r req-runtime.txt

COPY app.py bot.py ./
COPY data ./data

RUN useradd -m appuser
USER appuser

EXPOSE 8501
HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8501/_stcore/health')"
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.headless=true"]
