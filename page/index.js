// index putrefacto
const abelito = 'https://funkyatlas.abelitogamer.com';
console.log("hola");

// Método 1: debugger timing
setInterval(() => {
  const start = performance.now();
  debugger;
  if (performance.now() - start > 50) {
    window.location.replace(abelito);
  }
}, 500);

// Método 2: console detector
const detector = /./;
detector.toString = () => {
  window.location.replace(abelito);
  return '';
};
setInterval(() => {
  console.log(detector);
  console.clear();
}, 1000);

// Método 3: resize (el más confiable)
function checkDevTools() {
  if (
    window.outerWidth - window.innerWidth > 160 ||
    window.outerHeight - window.innerHeight > 160
  ) {
    window.location.replace(abelito);
  }
}
window.addEventListener('resize', checkDevTools);
checkDevTools(); // chequeo al cargar por si ya estaba abierto
