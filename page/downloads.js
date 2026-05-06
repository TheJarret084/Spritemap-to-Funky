/* ── downloads.js – */

function getOS() {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes("android")) return "Android";
  if (ua.includes("win"))     return "Windows";
  if (ua.includes("linux"))   return "Linux";
  return "Unknown";
}

const userOS = getOS();

const downloads = [
  {
    id: "linux",
    title: "Linux x64",
    os: "Linux",
    file: "Spritemap_to_Funky-linux-x64.tar.gz",
    download: "https://github.com/TheJarret084/Spritemap-to-Funky/releases/download/v1.0.0-beta.3/Spritemap_to_Funky-linux-x64.tar.gz",
    release: "https://github.com/TheJarret084/Spritemap-to-Funky/releases/tag/v1.0.0-beta.3"
  },
  {
    id: "windows",
    title: "Windows x64",
    os: "Windows",
    file: "Spritemap_to_Funky-windows-x64.zip",
    download: "https://github.com/TheJarret084/Spritemap-to-Funky/releases/download/v1.0.0-beta.3/Spritemap_to_Funky-windows-x64.zip",
    release: "https://github.com/TheJarret084/Spritemap-to-Funky/releases/tag/v1.0.0-beta.3"
  },
  {
    id: "android",
    title: "Android 32 y 64 bits",
    os: "Android",
    file: "SpritemaptoFunky.apk",
    download: "https://github.com/TheJarret084/Spritemap-to-Funky/releases/download/V-Android_1.0.0/SpritemaptoFunky.apk",
    release: "https://github.com/TheJarret084/Spritemap-to-Funky/releases/tag/V-Android_1.0.0"
  }
];

function createDownloadCard(d, isRecommended) {
  const card = document.createElement("div");
  card.className = "card";

  const downloadButton = d.download
    ? `<a class="btn ${isRecommended ? "recommended" : ""}" href="${d.download}">
         ${isRecommended ? "Descarga recomendada" : "Descargar"}
       </a>`
    : `<button class="btn disabled" type="button">Próximamente</button>`;

  const releaseButton = d.release
    ? `<a class="btn secondary" href="${d.release}">Ver release</a>`
    : "";

  card.innerHTML = `
    <h2>${d.title}</h2>
    <p class="muted">Archivo: ${d.file}</p>
    <div class="row">
      ${downloadButton}
      ${releaseButton}
    </div>
  `;

  return card;
}

document.addEventListener("DOMContentLoaded", () => {
  const downloadsContainer   = document.getElementById("downloads");
  const recommendedContainer = document.getElementById("recommended");
  const osLabel              = document.getElementById("detected-os");

  if (osLabel) {
    osLabel.textContent = userOS === "Unknown" ? "no reconocido" : userOS;
  }

  if (!downloadsContainer) return;

  const recommended = downloads.find(d => d.os === userOS && d.download);

  if (recommendedContainer) {
    recommendedContainer.innerHTML = "";

    if (recommended) {
      const recCard = document.createElement("div");
      recCard.className = "card";
      recCard.innerHTML = `
        <h2>Descarga recomendada</h2>
        <p class="muted">Detectamos que usas <strong>${userOS}</strong>.</p>
        <div class="row" style="margin-top:12px;">
          <a class="btn recommended" href="${recommended.download}">
            Descargar ${recommended.title}
          </a>
          <a class="btn secondary" href="${recommended.release}">
            Ver release
          </a>
        </div>
      `;
      recommendedContainer.appendChild(recCard);
    } else {
      const info = document.createElement("div");
      info.className = "card";
      info.innerHTML = `
        <h2>No hay descarga recomendada</h2>
        <p class="muted">No pude detectar un sistema compatible. Mira las opciones de abajo.</p>
      `;
      recommendedContainer.appendChild(info);
    }
  }

  downloadsContainer.innerHTML = "";
  downloads.forEach(d => {
    const isRecommended = d.os === userOS && !!d.download;
    downloadsContainer.appendChild(createDownloadCard(d, isRecommended));
  });
});
