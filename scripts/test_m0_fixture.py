import http.client, json, unittest
from urllib.parse import urlsplit
from m0_fixture import servers

class FixtureTests(unittest.TestCase):
    def test_two_origins_and_fixture_contract(self):
        with servers() as origins:
            self.assertNotEqual(origins[0], origins[1])
            conn = http.client.HTTPConnection(urlsplit(origins[0]).hostname, urlsplit(origins[0]).port)
            conn.request('GET', '/')
            r = conn.getresponse(); self.assertEqual(r.status, 200)
            self.assertIn(b'indexedDB.open', r.read())
            conn.request('GET', '/cookie?value=fixture-token')
            r = conn.getresponse(); cookies = r.headers.get_all('Set-Cookie'); r.read()
            self.assertEqual(len(cookies), 2)
            self.assertIn('HttpOnly', cookies[1]); self.assertIn('Max-Age=86400', cookies[0])
            conn.request('GET', '/echo-cookie', headers={'Cookie': '; '.join(c.split(';')[0] for c in cookies)})
            r = conn.getresponse(); self.assertEqual(json.loads(r.read())['httpOnly'], 'fixture-token')
            conn.request('GET', '/redirect')
            r = conn.getresponse(); self.assertEqual(r.status, 302); self.assertEqual(r.headers['Location'], '/page?redirected=1'); r.read()
            conn.request('POST', '/post', 'text=local-test-only')
            r = conn.getresponse(); self.assertEqual(json.loads(r.read())['received']['text'], ['local-test-only'])
            conn.request('GET', '/download')
            r = conn.getresponse(); self.assertIn('attachment', r.headers['Content-Disposition']); self.assertIn(b'fixture download', r.read())
            conn.request('GET', '/cookie?value=bad%0D%0Aheader')
            r = conn.getresponse(); self.assertEqual(r.status, 400); r.read()
            conn.close()

if __name__ == '__main__': unittest.main()
