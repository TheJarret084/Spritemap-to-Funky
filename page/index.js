const abelito = 'https://funkyatlas.abelitogamer.com';
console.log("hola");

const isMobile = /Android|iPhone|iPad|iPod/.test(navigator.userAgent);

// Solo en desktop
if (!isMobile) {
  setInterval(() => {
    const start = performance.now();
    debugger;
    if (performance.now() - start > 50) {
      window.location.replace(abelito);
    }
  }, 500);
}