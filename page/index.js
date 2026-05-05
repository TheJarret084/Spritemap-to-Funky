const abelito = 'https://funkyatlas.abelitogamer.com';
console.log("hola");

const isMobile = /Android|iPhone|iPad|iPod/.test(navigator.userAgent);

// Solo en desktop, método 1
if (!isMobile) {
  setInterval(() => {
    const start = performance.now();
    debugger;
    if (performance.now() - start > 50) {
      window.location.replace(abelito);
    }
  }, 500);
}

// Método 2: desactivado (muy agresivo)
// const detector = /./;
// detector.toString = () => {
//   window.location.replace(abelito);
//   return '';
// };
// setInterval(() => {
//   console.log(detector);
//   console.clear();
// }, 1000);

// Método 3: resize más tolerante
function checkDevTools() {
  // Solo chequea si la diferencia es GRANDE (como si abres DevTools en desktop)
  if (
    window.outerWidth - window.innerWidth > 300 ||
    window.outerHeight - window.innerHeight > 300
  ) {
    window.location.replace(abelito);
  }
}
window.addEventListener('resize', checkDevTools);
checkDevTools();