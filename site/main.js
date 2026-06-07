const canvas = document.getElementById("hero-canvas");
const context = canvas.getContext("2d");

let width = 0;
let height = 0;
let deviceScale = 1;

function resize() {
  deviceScale = Math.min(window.devicePixelRatio || 1, 2);
  width = Math.floor(window.innerWidth);
  height = Math.floor(Math.max(window.innerHeight, 760));
  canvas.width = Math.floor(width * deviceScale);
  canvas.height = Math.floor(height * deviceScale);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  context.setTransform(deviceScale, 0, 0, deviceScale, 0, 0);
}

function ribbon(points, offset, color, widthScale, time) {
  context.beginPath();
  for (let index = 0; index < points; index += 1) {
    const progress = index / (points - 1);
    const x = progress * width;
    const y =
      height * offset +
      Math.sin(progress * 5.2 + time) * height * 0.08 +
      Math.sin(progress * 12.8 - time * 0.68) * height * 0.025;
    if (index === 0) {
      context.moveTo(x, y);
    } else {
      context.lineTo(x, y);
    }
  }
  context.lineWidth = Math.max(90, width * widthScale);
  context.lineCap = "round";
  context.strokeStyle = color;
  context.stroke();
}

function frame(now) {
  const time = now * 0.00022;
  const gradient = context.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, "#051524");
  gradient.addColorStop(0.35, "#0d3a5d");
  gradient.addColorStop(0.63, "#647dbe");
  gradient.addColorStop(1, "#d7e4df");
  context.fillStyle = gradient;
  context.fillRect(0, 0, width, height);

  ribbon(160, 0.42, "rgba(18, 76, 164, 0.62)", 0.11, time);
  ribbon(160, 0.58, "rgba(163, 202, 232, 0.54)", 0.16, time * 1.2 + 1.5);
  ribbon(160, 0.32, "rgba(92, 65, 214, 0.42)", 0.10, -time * 0.9);
  ribbon(160, 0.74, "rgba(238, 245, 241, 0.50)", 0.18, -time * 0.7 + 2.4);

  context.beginPath();
  context.moveTo(-40, height * 0.58);
  context.bezierCurveTo(width * 0.18, height * 0.50, width * 0.36, height * 0.72, width + 40, height * 0.32);
  context.lineWidth = 4;
  context.strokeStyle = "rgba(255, 255, 255, 0.58)";
  context.stroke();

  window.requestAnimationFrame(frame);
}

resize();
window.addEventListener("resize", resize);
window.requestAnimationFrame(frame);
