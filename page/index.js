const abelito = 'https://funkyatlas.abelitogamer.com';
console.log("hola");

const isAndroid = /Android/.test(navigator.userAgent);

// Si NO es Android, activa anti-devtools
if (!isAndroid) {
  setInterval(() => {
    const start = performance.now();
    debugger;
    if (performance.now() - start > 50) {
      window.location.replace(abelito);
    }
  }, 500);

  const detector = /./;
  detector.toString = () => {
    window.location.replace(abelito);
    return '';
  };
  setInterval(() => {
    console.log(detector);
    console.clear();
  }, 1000);

  function checkDevTools() {
    if (
      window.outerWidth - window.innerWidth > 160 ||
      window.outerHeight - window.innerHeight > 160
    ) {
      window.location.replace(abelito);
    }
  }
  window.addEventListener('resize', checkDevTools);
  checkDevTools();
}