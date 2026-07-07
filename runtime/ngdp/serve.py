import http.server, os
DOC='/var/home/blizz/Projects/draenor-dit/runtime/ngdp'
DATA='/var/home/blizz/Projects/draenor-dit/wod/Data'
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        p=self.path.split('?',1)[0]
        # product-agnostic: any /<product>/versions or /<product>/cdns
        if p.endswith('/versions'): fn=DOC+'/wow_beta/versions'
        elif p.endswith('/cdns'): fn=DOC+'/wow_beta/cdns'
        elif p.startswith('/tpr/wow/'): fn=DATA+p[len('/tpr/wow'):]
        else: self.send_error(404); return
        if not os.path.isfile(fn): self.send_error(404); return
        b=open(fn,'rb').read()
        self.send_response(200)
        self.send_header('Content-Type','text/plain; charset=utf-8')
        self.send_header('Content-Length',str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def log_message(self,f,*a): print("HTTP", self.address_string(), self.path)
http.server.HTTPServer(('127.0.0.1',80),H).serve_forever()
