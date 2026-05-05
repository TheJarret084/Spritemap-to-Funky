const abelito = 'https://funkyatlas.abelitogamer.com';

const isMobile = /Android|iPhone|iPad|iPod/.test(navigator.userAgent);

// Mostrar en la página si es mobile o no
document.body.innerHTML += `<div style="position:fixed;top:0;left:0;background:red;color:white;padding:10px;z-index:9999;font-size:12px;">Mobile: ${isMobile}</div>`;

if (!isMobile) {
  setInterval(() => {
    const start = performance.now();
    debugger;
    if (performance.now() - start > 50) {
      window.location.replace(abelito);
    }
  }, 500);
}