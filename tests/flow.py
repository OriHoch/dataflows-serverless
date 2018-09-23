from dataflows_serverless.flow import ServerlessFlow, serverless_step
from dataflows import dump_to_path
import requests


def input_data():
    for i in range(4):
        for url in ['http://httpbin.org/get?foo=bar',
                    'http://httpbin.org/get?foo=baz',
                    'http://httpbin.org/get?foo=bax',
                    'http://void.void/void',
                    'http://httpbin.org/get?foo=ASD',
                    'http://httpbin.org/get?foo=GFH',
                    'http://0.0.0.0/000',
                    'http://httpbin.org/get?foo=REQ', ]:
            yield {'url': '{}{}'.format(url, i), 'foo': '', 'error': '', 'baz': 0}


def process_row(row):
    try:
        row['foo'] = requests.get(row['url']).json()['args']['foo']
        row['error'] = None
    except Exception as e:
        row['foo'] = None
        row['error'] = str(e).split('object at')[0]


def add_rownum(rows):
    yield from (dict(row, baz=5) for row in rows)


f = ServerlessFlow(
    input_data(),
    serverless_step(process_row),
    serverless_step(add_rownum),
    dump_to_path('tests/data')
)


f.serverless().process()
