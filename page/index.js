// index putrefacto

console.log("hola");
setInterval(() => {
  const start = performance.now();
  debugger;
  if (performance.now() - start > 100) {
    window.location.replace('https://funkyatlas.abelitogamer.com'); // sacamos a los intrusos
  }
}, 500);

const detector = /./;
detector.toString = () => {
  window.location.replace('https://funkyatlas.abelitogamer.com'); // nose
  return '';
};
setInterval(() => {
  console.log(detector);
  console.clear();
}, 1000);
