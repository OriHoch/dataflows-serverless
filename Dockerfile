FROM alpine:3.8

RUN apk update &&\
    apk add --no-cache git ca-certificates openssh-client openssl-dev \
                       python3-dev py3-chardet py3-setuptools \
                       musl libc6-compat linux-headers build-base bash libffi-dev &&\
    pip3 install --upgrade pip &&\
    pip3 install --upgrade pipenv

COPY Pipfile Pipfile.lock /tmp/dataflows_serverless/
RUN cd /tmp/dataflows_serverless/ && pipenv install --system --deploy

COPY README.md VERSION.txt setup.py /tmp/dataflows_serverless/
COPY dataflows_serverless/ /tmp/dataflows_serverless/dataflows_serverless/
RUN pip3 install /tmp/dataflows_serverless && rm -rf /tmp/dataflows_serverless

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
