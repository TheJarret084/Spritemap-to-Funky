const abelito = 'https://funkyatlas.abelitogamer.com';

console.log('hola');

(function () {
  const isAndroid = /Android/i.test(navigator.userAgent);

  // Android queda fuera por completo
  if (isAndroid) return;

  let triggered = false;

  function kick() {
    if (triggered) return;
    triggered = true;
    window.location.replace(abelito);
  }

  // 1) Detecta pausa real por debugger
  function checkDebugger() {
    const start = performance.now();
    debugger;
    const elapsed = performance.now() - start;

    // Umbral más relajado para evitar falsos positivos
    if (elapsed > 120) {
      kick();
    }
  }

  // 2) Detecta cambios típicos cuando la consola está abierta
  function checkConsole() {
    const threshold = 160;
    const widthDiff = Math.abs(window.outerWidth - window.innerWidth);
    const heightDiff = Math.abs(window.outerHeight - window.innerHeight);

    if (widthDiff > threshold || heightDiff > threshold) {
      kick();
    }
  }

  // 3) Truco de consola, sin hacerlo demasiado agresivo
  function checkConsoleOpen() {
    const bait = new Image();

    Object.defineProperty(bait, 'id', {
      get() {
        kick();
        return '';
      }
    });

    console.log(bait);
    console.clear();
  }

  // Ejecutar con intervalos suaves
  const t1 = setInterval(checkDebugger, 1000);
  const t2 = setInterval(checkConsole, 1500);
  const t3 = setInterval(checkConsoleOpen, 2000);

  // Revisión al redimensionar
  window.addEventListener('resize', checkConsole);

  // Limpieza si ya redirigió
  const stopIfTriggered = setInterval(() => {
    if (triggered) {
      clearInterval(t1);
      clearInterval(t2);
      clearInterval(t3);
      clearInterval(stopIfTriggered);
      window.removeEventListener('resize', checkConsole);
    }
  }, 300);
})();