<script>
  import { onMount } from 'svelte';

  let videoElement;
  let canvasElement;
  let context;
  let mediaStream;
  let isInverted = false;
  let videoDevices = [];
  let selectedDeviceId = '';

  // Ajout d'un canvas visible pour le flux vidéo
  let displayCanvas;
  let displayContext;
  let animationFrameId;

  let contrast = 100; // valeur par défaut (100 = pas de changement)
  let exposure = 0; // valeur par défaut (0 = pas de changement)

  let isCropping = false;
  let cropArea = {
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    isDragging: false,
    isResizing: false,
    dragStart: { x: 0, y: 0 },
    resizeEdge: {
      right: false,
      bottom: false,
      left: false,
      top: false
    }
  };

  let mode = 'camera'; // 'camera' ou 'import'
  let isDragging = false;
  let imageFile = null;

  let updateDisplay = () => {
    if (!videoElement || !displayCanvas) return;
    
    displayCanvas.width = videoElement.videoWidth;
    displayCanvas.height = videoElement.videoHeight;
    
    displayContext.drawImage(videoElement, 0, 0);
    
    const imageData = displayContext.getImageData(0, 0, displayCanvas.width, displayCanvas.height);
    const data = imageData.data;
    
    const contrastFactor = (contrast / 100);
    const exposureFactor = Math.pow(2, exposure); // Conversion exponentielle pour l'exposition

    for (let i = 0; i < data.length; i += 4) {
      // Appliquer l'exposition et le contraste
      for (let j = 0; j < 3; j++) {
        let color = data[i + j];
        
        // Appliquer l'exposition
        color *= exposureFactor;
        
        // Appliquer le contraste
        color = contrastFactor * (color - 128) + 128;
        
        // Limiter les valeurs entre 0 et 255
        data[i + j] = Math.min(255, Math.max(0, color));
      }
      
      // Appliquer l'inversion si activée
      if (isInverted) {
        data[i] = 255 - data[i];
        data[i + 1] = 255 - data[i + 1];
        data[i + 2] = 255 - data[i + 2];
      }
    }
    
    displayContext.putImageData(imageData, 0, 0);
    animationFrameId = requestAnimationFrame(updateDisplay);
  };

  async function getVideoDevices() {
    try {
      if (!navigator.mediaDevices) {
        console.warn('MediaDevices API non disponible. Vérifiez que vous utilisez HTTPS ou localhost.');
        return [];
      }
      const devices = await navigator.mediaDevices.enumerateDevices();
      return devices.filter(device => device.kind === 'videoinput');
    } catch (error) {
      console.error('Erreur lors de la récupération des périphériques vidéo : ', error);
      return [];
    }
  }

  async function updateVideoDevicesList() {
    videoDevices = await getVideoDevices();
    if (videoDevices && videoDevices.length > 0 && !selectedDeviceId) {
      selectedDeviceId = videoDevices[0].deviceId;
      await startCapture();
    }
  }

  async function startCapture() {
    try {
      if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
      }
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
      }

      const constraints = {
        video: {
          deviceId: selectedDeviceId,
          facingMode: { ideal: "environment" },
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        }
      };
      mediaStream = await navigator.mediaDevices.getUserMedia(constraints);
      videoElement.srcObject = mediaStream;
      
      // Attendre que la vidéo soit prête
      await videoElement.play();
      updateDisplay();
    } catch (error) {
      console.error('Erreur lors de l\'accès à la webcam : ', error);
    }
  }

  function capturePhoto() {
    // Utiliser le canvas d'affichage pour la capture
    canvasElement.width = displayCanvas.width;
    canvasElement.height = displayCanvas.height;
    context.drawImage(displayCanvas, 0, 0);
    
    const imageBase64 = canvasElement.toDataURL('image/jpeg');
    const imageElement = document.createElement('img');
    imageElement.src = imageBase64;
    document.body.appendChild(imageElement);
  }

  function handleKeydown(event) {
    if (event.code === 'Space') {
      capturePhoto();
    }
  }

  function startCrop() {
    isCropping = true;
    // Initialiser la zone de recadrage au centre avec une taille par défaut
    const canvasRect = displayCanvas.getBoundingClientRect();
    cropArea.width = canvasRect.width * 0.5;
    cropArea.height = cropArea.width;
    cropArea.x = (canvasRect.width - cropArea.width) / 2;
    cropArea.y = (canvasRect.height - cropArea.height) / 2;
  }

  function handleCropMouseDown(event) {
    if (!isCropping) return;
    
    const canvasRect = displayCanvas.getBoundingClientRect();
    const x = event.clientX - canvasRect.left;
    const y = event.clientY - canvasRect.top;
    
    // Vérifier si on clique sur les poignées de redimensionnement
    const margin = 10;
    const onRightEdge = Math.abs(x - (cropArea.x + cropArea.width)) < margin;
    const onBottomEdge = Math.abs(y - (cropArea.y + cropArea.height)) < margin;
    const onLeftEdge = Math.abs(x - cropArea.x) < margin;
    const onTopEdge = Math.abs(y - cropArea.y) < margin;
    
    cropArea.resizeEdge = {
      right: onRightEdge,
      bottom: onBottomEdge,
      left: onLeftEdge,
      top: onTopEdge
    };
    
    if (Object.values(cropArea.resizeEdge).some(edge => edge)) {
      cropArea.isResizing = true;
    } else if (x >= cropArea.x && x <= cropArea.x + cropArea.width &&
               y >= cropArea.y && y <= cropArea.y + cropArea.height) {
      cropArea.isDragging = true;
    }
    
    cropArea.dragStart = { x, y };
  }

  function handleCropMouseMove(event) {
    if (!isCropping || (!cropArea.isDragging && !cropArea.isResizing)) return;
    
    const canvasRect = displayCanvas.getBoundingClientRect();
    const x = event.clientX - canvasRect.left;
    const y = event.clientY - canvasRect.top;
    
    if (cropArea.isResizing) {
      const minSize = 50; // Taille minimale en pixels
      
      if (cropArea.resizeEdge.right) {
        const newWidth = Math.max(minSize, x - cropArea.x);
        cropArea.width = Math.min(newWidth, canvasRect.width - cropArea.x);
      }
      if (cropArea.resizeEdge.bottom) {
        const newHeight = Math.max(minSize, y - cropArea.y);
        cropArea.height = Math.min(newHeight, canvasRect.height - cropArea.y);
      }
      if (cropArea.resizeEdge.left) {
        const maxX = cropArea.x + cropArea.width - minSize;
        const newX = Math.min(x, maxX);
        const newWidth = cropArea.x + cropArea.width - newX;
        if (newX >= 0 && newWidth >= minSize) {
          cropArea.x = newX;
          cropArea.width = newWidth;
        }
      }
      if (cropArea.resizeEdge.top) {
        const maxY = cropArea.y + cropArea.height - minSize;
        const newY = Math.min(y, maxY);
        const newHeight = cropArea.y + cropArea.height - newY;
        if (newY >= 0 && newHeight >= minSize) {
          cropArea.y = newY;
          cropArea.height = newHeight;
        }
      }
    } else if (cropArea.isDragging) {
      const dx = x - cropArea.dragStart.x;
      const dy = y - cropArea.dragStart.y;
      
      cropArea.x = Math.max(0, Math.min(cropArea.x + dx, canvasRect.width - cropArea.width));
      cropArea.y = Math.max(0, Math.min(cropArea.y + dy, canvasRect.height - cropArea.height));
      cropArea.dragStart = { x, y };
    }
  }

  function handleCropMouseUp() {
    cropArea.isDragging = false;
    cropArea.isResizing = false;
  }

  // Ajouter un attribut willReadFrequently au canvas
  function initCanvas(canvas) {
    return canvas.getContext('2d', { willReadFrequently: true });
  }

  function applyCrop() {
    // Calculer les dimensions réelles pour le recadrage
    const scaleX = displayCanvas.width / displayCanvas.getBoundingClientRect().width;
    const scaleY = displayCanvas.height / displayCanvas.getBoundingClientRect().height;
    
    const realCropArea = {
      x: cropArea.x * scaleX,
      y: cropArea.y * scaleY,
      width: cropArea.width * scaleX,
      height: cropArea.height * scaleY
    };

    // Créer un canvas temporaire pour le recadrage
    const tempCanvas = document.createElement('canvas');
    tempCanvas.width = realCropArea.width;
    tempCanvas.height = realCropArea.height;
    const tempContext = initCanvas(tempCanvas);

    // Copier la partie recadrée
    tempContext.drawImage(
      displayCanvas,
      realCropArea.x, realCropArea.y,
      realCropArea.width, realCropArea.height,
      0, 0,
      realCropArea.width, realCropArea.height
    );

    if (mode === 'camera') {
      // Mode caméra : redémarrer la capture avec les nouvelles dimensions
      if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
      }
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
      }

      const constraints = {
        video: {
          deviceId: selectedDeviceId,
          width: { ideal: videoElement.videoWidth },
          height: { ideal: videoElement.videoHeight }
        }
      };

      // Stocker les dimensions du recadrage
      const cropSettings = {
        x: realCropArea.x,
        y: realCropArea.y,
        width: realCropArea.width,
        height: realCropArea.height
      };

      // Redémarrer la capture
      navigator.mediaDevices.getUserMedia(constraints)
        .then(stream => {
          mediaStream = stream;
          videoElement.srcObject = stream;
          
          displayCanvas.width = cropSettings.width;
          displayCanvas.height = cropSettings.height;
          canvasElement.width = cropSettings.width;
          canvasElement.height = cropSettings.height;

          const processCanvas = document.createElement('canvas');
          processCanvas.width = videoElement.videoWidth || 1920;
          processCanvas.height = videoElement.videoHeight || 1080;
          const processContext = initCanvas(processCanvas);

          updateDisplay = function() {
            if (!videoElement || !displayCanvas || !videoElement.videoWidth) return;
            processContext.drawImage(videoElement, 0, 0);
            displayContext.drawImage(
              processCanvas,
              cropSettings.x, cropSettings.y,
              cropSettings.width, cropSettings.height,
              0, 0,
              cropSettings.width, cropSettings.height
            );
            applyEffects();
            animationFrameId = requestAnimationFrame(updateDisplay);
          };

          return videoElement.play();
        })
        .then(() => {
          updateDisplay();
          isCropping = false;
        })
        .catch(error => {
          console.error('Erreur lors du redémarrage de la capture :', error);
        });
    } else {
      // Mode import : recadrer l'image et mettre à jour l'affichage
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
      }

      // Mettre à jour les dimensions des canvas
      displayCanvas.width = realCropArea.width;
      displayCanvas.height = realCropArea.height;
      canvasElement.width = realCropArea.width;
      canvasElement.height = realCropArea.height;

      // Créer une nouvelle fonction updateDisplay pour l'image recadrée
      updateDisplay = function() {
        if (!displayCanvas) return;
        displayContext.drawImage(tempCanvas, 0, 0);
        applyEffects();
        animationFrameId = requestAnimationFrame(updateDisplay);
      };

      updateDisplay();
      isCropping = false;
    }
  }

  // Extraire l'application des effets dans une fonction séparée
  function applyEffects() {
    const imageData = displayContext.getImageData(0, 0, displayCanvas.width, displayCanvas.height);
    const data = imageData.data;

    const contrastFactor = (contrast / 100);
    const exposureFactor = Math.pow(2, exposure);

    for (let i = 0; i < data.length; i += 4) {
      for (let j = 0; j < 3; j++) {
        let color = data[i + j];
        color *= exposureFactor;
        color = contrastFactor * (color - 128) + 128;
        data[i + j] = Math.min(255, Math.max(0, color));
      }

      if (isInverted) {
        data[i] = 255 - data[i];
        data[i + 1] = 255 - data[i + 1];
        data[i + 2] = 255 - data[i + 2];
      }
    }

    displayContext.putImageData(imageData, 0, 0);
  }

  function handleDragEnter(e) {
    e.preventDefault();
    isDragging = true;
  }

  function handleDragLeave(e) {
    e.preventDefault();
    isDragging = false;
  }

  function handleDrop(e) {
    e.preventDefault();
    isDragging = false;
    const file = e.dataTransfer.files[0];
    if (file && file.type.startsWith('image/')) {
      loadImage(file);
    }
  }

  function handleFileSelect(e) {
    const file = e.target.files[0];
    if (file && file.type.startsWith('image/')) {
      loadImage(file);
    }
  }

  function loadImage(file) {
    const reader = new FileReader();
    reader.onload = function(e) {
      const img = new Image();
      img.onload = function() {
        // Stocker l'image originale pour pouvoir réappliquer les effets
        const originalCanvas = document.createElement('canvas');
        originalCanvas.width = img.width;
        originalCanvas.height = img.height;
        const originalContext = originalCanvas.getContext('2d');
        originalContext.drawImage(img, 0, 0);

        // Configurer le canvas d'affichage
        displayCanvas.width = img.width;
        displayCanvas.height = img.height;
        
        // Modifier updateDisplay pour l'image importée
        updateDisplay = function() {
          if (!displayCanvas) return;

          // Copier l'image originale
          displayContext.drawImage(originalCanvas, 0, 0);

          // Appliquer les effets
          const imageData = displayContext.getImageData(0, 0, displayCanvas.width, displayCanvas.height);
          const data = imageData.data;

          const contrastFactor = (contrast / 100);
          const exposureFactor = Math.pow(2, exposure);

          for (let i = 0; i < data.length; i += 4) {
            for (let j = 0; j < 3; j++) {
              let color = data[i + j];
              color *= exposureFactor;
              color = contrastFactor * (color - 128) + 128;
              data[i + j] = Math.min(255, Math.max(0, color));
            }

            if (isInverted) {
              data[i] = 255 - data[i];
              data[i + 1] = 255 - data[i + 1];
              data[i + 2] = 255 - data[i + 2];
            }
          }

          displayContext.putImageData(imageData, 0, 0);
          animationFrameId = requestAnimationFrame(updateDisplay);
        };

        imageFile = file;
        mode = 'import';
        if (mediaStream) {
          mediaStream.getTracks().forEach(track => track.stop());
        }
        
        // Démarrer la boucle d'affichage
        updateDisplay();
      };
      // Ajouter une vérification de type
      if (typeof e.target.result === 'string') {
        img.src = e.target.result;
      }
    };
    reader.readAsDataURL(file);
  }

  function switchMode(newMode) {
    mode = newMode;
    if (mode === 'camera') {
      startCapture();
    } else {
      if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
      }
      if (!imageFile) {
        displayCanvas.width = 1920;
        displayCanvas.height = 1080;
        displayContext.fillStyle = '#262626';
        displayContext.fillRect(0, 0, displayCanvas.width, displayCanvas.height);
      }
    }
  }

  onMount(() => {
    // Initialiser les contextes avec willReadFrequently
    context = initCanvas(canvasElement);
    displayContext = initCanvas(displayCanvas);
    updateVideoDevicesList();
    
    return () => {
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
      }
      if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
      }
    };
  });
</script>

<svelte:window on:keydown={handleKeydown}/>

<div class="container">
  <div class="mode-selector">
    <button 
      class={mode === 'camera' ? 'active' : ''} 
      on:click={() => switchMode('camera')}
    >
      Mode Caméra
    </button>
    <button 
      class={mode === 'import' ? 'active' : ''} 
      on:click={() => switchMode('import')}
    >
      Mode Import
    </button>
  </div>

  <div class="video-container">
    {#if mode === 'camera'}
      <video
        bind:this={videoElement}
        autoplay
        playsinline
        class="hidden"
      ></video>
    {/if}
    
    <canvas
      bind:this={displayCanvas}
      class="display-canvas"
    ></canvas>
    
    <canvas
      bind:this={canvasElement}
      class="hidden"
    ></canvas>

    {#if mode === 'import' && !imageFile}
      <div 
        class="drop-zone {isDragging ? 'dragging' : ''}"
        on:dragenter={handleDragEnter}
        on:dragover|preventDefault
        on:dragleave={handleDragLeave}
        on:drop={handleDrop}
      >
        <div class="drop-content">
          <p>Glissez une image ici</p>
          <p>ou</p>
          <label class="file-input-label">
            Choisir un fichier
            <input 
              type="file" 
              accept="image/*" 
              on:change={handleFileSelect}
              class="hidden"
            >
          </label>
        </div>
      </div>
    {/if}

    {#if isCropping}
      <div 
        class="crop-overlay"
        on:mousedown={handleCropMouseDown}
        on:mousemove={handleCropMouseMove}
        on:mouseup={handleCropMouseUp}
        on:mouseleave={handleCropMouseUp}
      >
        <div 
          class="crop-area"
          style="
            left: {cropArea.x}px;
            top: {cropArea.y}px;
            width: {cropArea.width}px;
            height: {cropArea.height}px;
          "
        >
          <div class="resize-handle top-left"></div>
          <div class="resize-handle top-right"></div>
          <div class="resize-handle bottom-left"></div>
          <div class="resize-handle bottom-right"></div>
          <div class="resize-handle left"></div>
          <div class="resize-handle right"></div>
          <div class="resize-handle top"></div>
          <div class="resize-handle bottom"></div>
        </div>
      </div>
    {/if}
  </div>

  <div class="controls">
    <div class="control-group">
      <select
        bind:value={selectedDeviceId}
        on:change={startCapture}
      >
        {#each videoDevices as device}
          <option value={device.deviceId}>
            {device.label || `Caméra ${videoDevices.indexOf(device) + 1}`}
          </option>
        {/each}
      </select>

      <button on:click={capturePhoto}>
        Capturer la photo
      </button>

      <button 
        class={isInverted ? 'active' : ''} 
        on:click={() => isInverted = !isInverted}
      >
        {isInverted ? "Désactiver l'inversion" : "Inverser les couleurs"}
      </button>

      {#if !isCropping}
        <button on:click={startCrop}>
          Recadrer
        </button>
      {:else}
        <button class="active" on:click={applyCrop}>
          Valider le recadrage
        </button>
      {/if}
    </div>

    <div class="control-group">
      <div class="slider-control">
        <label for="contrast">Contraste: {contrast}%</label>
        <input 
          type="range" 
          id="contrast" 
          min="0" 
          max="200" 
          bind:value={contrast}
        >
      </div>

      <div class="slider-control">
        <label for="exposure">Exposition: {exposure > 0 ? '+' : ''}{exposure}</label>
        <input 
          type="range" 
          id="exposure" 
          min="-2" 
          max="2" 
          step="0.1"
          bind:value={exposure}
        >
      </div>
    </div>
  </div>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow-y: auto;
    min-height: 100vh;
  }

  .container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    padding: 0.5rem;
    width: 100vw;
    box-sizing: border-box;
    min-height: 100vh;
  }

  .video-container {
    position: relative;
    width: 100vw;
    height: auto;
    aspect-ratio: 3/4;  /* Plus haut que large pour le mobile */
  }

  video {
    width: 100%;
    height: auto;
  }

  .controls {
    width: 100%;
    padding: 0.5rem;
    background: rgba(0, 0, 0, 0.8);
    gap: 0.5rem;
    margin-top: 1rem;
    border-radius: 8px;
    position: relative;  /* Assure que les contrôles restent dans le flux */
  }

  .control-group {
    flex-direction: column;
    width: 100%;
  }

  .slider-control {
    width: 100%;
    min-width: unset;
  }

  @media (min-width: 768px) {
    .container {
      padding: 1rem;
    }

    .control-group {
      flex-direction: row;
    }

    .controls {
      padding: 1.5rem;
    }

    .slider-control {
      min-width: 200px;
    }
  }

  /* Ajuster les boutons pour mobile */
  button {
    width: 100%;
    margin: 0.2rem 0;
  }

  @media (min-width: 768px) {
    button {
      width: auto;
      margin: 0;
    }
  }

  /* Ajuster le sélecteur de caméra */
  select {
    width: 100%;
    margin: 0.2rem 0;
  }

  @media (min-width: 768px) {
    select {
      width: auto;
      min-width: 200px;
    }
  }

  .display-canvas {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  .hidden {
    display: none;
  }

  button {
    padding: 0.7rem 1.2rem;
    background-color: #333;
    color: white;
    border: 1px solid #444;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s ease;
  }

  button:hover {
    background-color: #444;
    border-color: #666;
  }

  select {
    padding: 0.7rem;
    border-radius: 4px;
    background: #333;
    color: white;
    border: 1px solid #444;
    cursor: pointer;
    min-width: 200px;
  }

  select:focus {
    outline: none;
    border-color: #666;
  }

  .crop-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    cursor: move;
  }

  .crop-area {
    position: absolute;
    border: 2px solid white;
    box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.5);
    cursor: move;
  }

  .resize-handle {
    position: absolute;
    width: 10px;
    height: 10px;
    background: white;
    border-radius: 50%;
  }

  /* Poignées de redimensionnement aux quatre coins */
  .resize-handle.top-left {
    left: -5px;
    top: -5px;
    cursor: nw-resize;
  }

  .resize-handle.top-right {
    right: -5px;
    top: -5px;
    cursor: ne-resize;
  }

  .resize-handle.bottom-left {
    left: -5px;
    bottom: -5px;
    cursor: sw-resize;
  }

  .resize-handle.bottom-right {
    right: -5px;
    bottom: -5px;
    cursor: se-resize;
  }

  /* Poignées de redimensionnement sur les côtés */
  .resize-handle.left {
    left: -5px;
    top: 50%;
    transform: translateY(-50%);
    cursor: w-resize;
  }

  .resize-handle.right {
    right: -5px;
    top: 50%;
    transform: translateY(-50%);
    cursor: e-resize;
  }

  .resize-handle.top {
    top: -5px;
    left: 50%;
    transform: translateX(-50%);
    cursor: n-resize;
  }

  .resize-handle.bottom {
    bottom: -5px;
    left: 50%;
    transform: translateX(-50%);
    cursor: s-resize;
  }

  /* Groupe de contrôles spécifiques */
  .control-group {
    display: flex;
    gap: 1rem;
    align-items: center;
    padding: 0.5rem;
    border-radius: 4px;
  }

  /* Style pour les boutons actifs */
  button.active {
    background-color: #fff;
    color: #1a1a1a;
  }

  .mode-selector {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .drop-zone {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    border: 3px dashed #444;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(38, 38, 38, 0.9);
    transition: all 0.3s ease;
  }

  .drop-zone.dragging {
    background: rgba(38, 38, 38, 0.95);
    border-color: #666;
  }

  .drop-content {
    text-align: center;
    color: #fff;
  }

  .drop-content p {
    margin: 0.5rem 0;
  }

  .file-input-label {
    display: inline-block;
    padding: 0.7rem 1.2rem;
    background-color: #333;
    color: white;
    border: 1px solid #444;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .file-input-label:hover {
    background-color: #444;
    border-color: #666;
  }

  @media (orientation: portrait) {
    .video-container {
      height: 70vh;  /* Plus grand pour mieux voir l'image */
      aspect-ratio: unset;
    }

    .display-canvas {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }
</style> 