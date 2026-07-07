/**
 * Utility immagini lato client.
 * Le foto vengono ridimensionate e compresse PRIMA di salvarle in localStorage
 * (Fase A) o di caricarle sul cloud (Fase B): la quota localStorage è ~5MB.
 */

/**
 * Ridimensiona un file immagine e lo restituisce come dataURL JPEG.
 * @param {File|Blob} file
 * @param {number} maxDim - Lato massimo in px (default 600)
 * @param {number} quality - Qualità JPEG 0-1 (default 0.82)
 * @returns {Promise<string>} dataURL
 */
export function resizeImageFile(file, maxDim = 600, quality = 0.82) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();

    img.onload = () => {
      URL.revokeObjectURL(url);
      const scale = Math.min(1, maxDim / Math.max(img.width, img.height));
      const width = Math.round(img.width * scale);
      const height = Math.round(img.height * scale);

      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      // Fondo bianco per foto con trasparenza (il JPEG non ha alpha)
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, width, height);
      ctx.drawImage(img, 0, 0, width, height);

      try {
        resolve(canvas.toDataURL('image/jpeg', quality));
      } catch (e) {
        reject(e);
      }
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('image-load-failed'));
    };

    img.src = url;
  });
}
