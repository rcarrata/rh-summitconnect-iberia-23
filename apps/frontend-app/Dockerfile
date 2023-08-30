
FROM registry.fedoraproject.org/fedora-minimal

EXPOSE 8080

RUN microdnf -y install python-pip && microdnf clean all
RUN pip install httpx starlette sse_starlette uvicorn

USER 1001

COPY python /app/python
COPY static /app/static

WORKDIR /app

CMD ["python", "python/main.py"]
