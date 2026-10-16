"""Refresh the bundled public city/street index from the Population Authority.

Only public reference data is downloaded. No user addresses are sent to this API.
Run from any directory: python3 app/tool/update_israel_addresses.py
"""
import json
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen

RESOURCE = '9ad3862c-8391-4b2f-84a4-2d4c68625f4b'
API = 'https://data.gov.il/api/3/action/'


def fetch(action, **params):
    with urlopen(API + action + '?' + urlencode(params), timeout=60) as response:
        data = json.load(response)
    if not data.get('success'):
        raise RuntimeError('Government address dataset request failed')
    return data['result']


def main():
    metadata = fetch('resource_show', id=RESOURCE)
    cities = {}
    offset = 0
    while True:
        page = fetch('datastore_search', resource_id=RESOURCE, limit=10000, offset=offset)
        records = page['records']
        for row in records:
            city = str(row['שם_ישוב']).strip()
            street = str(row['שם_רחוב']).strip()
            if city:
                values = cities.setdefault(city, set())
                if street and street != city:
                    values.add(street)
        offset += len(records)
        if offset >= page['total']:
            break
        if not records:
            raise RuntimeError('Address download ended before all rows were received')
    if len(cities) < 1000 or offset < 60000:
        raise RuntimeError('Incomplete address index; existing asset was not changed')
    result = {
        'source': 'רשות האוכלוסין וההגירה · data.gov.il',
        'source_url': 'https://data.gov.il/dataset/' + metadata['package_id'],
        'resource_id': RESOURCE,
        'updated_at': metadata['last_modified'],
        'cities': {city: sorted(streets) for city, streets in sorted(cities.items())},
    }
    destination = Path(__file__).resolve().parents[1] / 'assets/addresses/israel_streets.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(f'{len(cities)} localities, {sum(map(len, cities.values()))} streets; {metadata["last_modified"]}')


if __name__ == '__main__':
    main()
