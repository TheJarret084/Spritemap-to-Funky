/* ── help.js – */

/* Abre automáticamente el <details> si el usuario llega con ?open en la URL. */
document.addEventListener("DOMContentLoaded", () => {
  const params = new URLSearchParams(window.location.search);
  if (params.has("open")) {
    const det = document.querySelector("details");
    if (det) det.open = true;
  }
});
