from mitmproxy import ctx

class CertGenerator:
    def running(self):
        """
        The running hook is called once mitmproxy has completed its setup.
        This is the perfect place to ensure the CA is generated.
        We then signal the proxy to quit immediately.
        """
        ctx.master.shutdown()

addons = [CertGenerator()]
