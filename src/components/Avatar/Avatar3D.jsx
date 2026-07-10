import { useEffect, useRef } from 'react';
import {
  Scene,
  PerspectiveCamera,
  WebGLRenderer,
  LatheGeometry,
  CylinderGeometry,
  CircleGeometry,
  SphereGeometry,
  MeshStandardMaterial,
  MeshBasicMaterial,
  Mesh,
  Group,
  Vector2,
  Color,
  AmbientLight,
  DirectionalLight,
  TextureLoader,
  RepeatWrapping,
  DoubleSide,
  SRGBColorSpace,
} from 'three';
import { bodyProfiles } from '../../utils/avatarMesh';
import { garmentParts, radiusAt } from '../../utils/garmentMesh';
import { garmentLayers } from '../../utils/tryonComposer';

const RADIAL_SEGMENTS = 32;
const DECAL_ARC = (140 * Math.PI) / 180;
const HEX_COLOR_RE = /^#[0-9a-fA-F]{6}$/;
const FALLBACK_COLOR = '#cfc7bb';

/** Colore sicuro: una stringa esadecimale malformata non deve sbagliare il
 * colore in silenzio, ripiega su un beige neutro. */
const safeColor = (hex) => new Color(HEX_COLOR_RE.test(hex || '') ? hex : FALLBACK_COLOR);

const lathe = (profile) =>
  new LatheGeometry(
    profile.map(([r, y]) => new Vector2(Math.max(r, 0.001), y)),
    RADIAL_SEGMENTS
  );

/**
 * Libera geometria, texture e materiale di ogni figlio della figura. Usata
 * sia al cambio di outfit (le mesh precedenti vanno rifatte) sia allo
 * smontaggio del componente: senza, le risorse GPU si accumulano a ogni
 * ricostruzione o non vengono mai liberate quando il componente sparisce.
 * Alcune mesh dello stesso capo condividono lo stesso materiale (la
 * piastrella di tessuto vale per busto e maniche): disporre due volte lo
 * stesso materiale/texture non è un problema, `dispose()` è idempotente.
 */
const clearFigure = (figure) => {
  while (figure.children.length) {
    const child = figure.children.pop();
    child.geometry?.dispose();
    child.material?.map?.dispose();
    child.material?.dispose();
  }
};

/**
 * Materiale del capo: la piastrella di tessuto vera (foto) ripetuta come
 * pattern, non il disegno intero del capo — quello aveva già collo, maniche
 * e orli propri, che schiacciati su un corpo diverso producevano la "piastra
 * sporgente" del vecchio decal cilindrico. Se non c'è una piastrella si
 * ripiega sul colore dominante.
 */
const garmentMaterial = (texture, onReady) => {
  if (texture?.swatchUrl) {
    const map = new TextureLoader().load(texture.swatchUrl, onReady);
    map.wrapS = RepeatWrapping;
    map.wrapT = RepeatWrapping;
    map.repeat.set(3, 3);
    map.colorSpace = SRGBColorSpace;
    return new MeshStandardMaterial({ map, color: 0xffffff, roughness: 0.95 });
  }
  return new MeshStandardMaterial({ color: safeColor(texture?.colorHex), roughness: 0.95 });
};

/**
 * La stampa del capo (logo, scritta...) rimessa esattamente dove stava sulla
 * foto vera, sulla parte principale del capo. `printAt` è in frazioni del
 * rettangolo del capo fotografato: cx/cy il centro, w/h la dimensione.
 *
 * Per i capi sdoppiati (mirror: true, es. pantaloni) `printAt.cx` è misurato
 * sull'intera foto che contiene due gambe: va prima scelta la gamba (sinistra
 * se cx < 0.5) e poi ricalcolata la frazione locale a quella sola gamba,
 * altrimenti l'angolo attorno all'asse cadrebbe nel posto sbagliato. Se la
 * stampa, ricalcolata, risulta più larga di mezzo capo (localW > 1) vuol dire
 * che è una fantasia diffusa su entrambe le gambe, non un logo da tasca: se
 * ne occupa già la piastrella di tessuto, qui si rinuncia.
 */
const printDecal = (mainPart, printUrl, printAt, onReady) => {
  const ys = mainPart.profile.map(([, y]) => y);
  const from = Math.min(...ys);
  const to = Math.max(...ys);

  let localCx = printAt.cx;
  let localW = printAt.w;
  let instanceX = 0;

  if (mainPart.mirror) {
    const onLeft = printAt.cx < 0.5;
    instanceX = onLeft ? -mainPart.offsetX : mainPart.offsetX;
    localCx = onLeft ? printAt.cx * 2 : (printAt.cx - 0.5) * 2;
    localW = printAt.w * 2;
    if (localW > 1) return null;
  }

  // `printAt.cy` è misurata dall'alto del capo, mentre y cresce verso l'alto.
  const y = to - printAt.cy * (to - from);
  const patchHeight = printAt.h * (to - from);

  // `printAt.cx` = 0.5 è il centro del davanti. Lo scarto orizzontale diventa
  // un angolo attorno all'asse: la stampa gira col corpo, resta incollata al
  // tessuto.
  const theta = (localCx - 0.5) * DECAL_ARC;
  const arc = localW * DECAL_ARC;
  const radius = radiusAt(mainPart.profile, y) + 0.004;

  const geometry = new CylinderGeometry(
    radius,
    radius,
    Math.max(patchHeight, 0.001),
    24,
    1,
    true,
    theta - arc / 2,
    arc
  );
  const material = new MeshStandardMaterial({
    transparent: true,
    side: DoubleSide,
    roughness: 0.9,
    // Il cilindro della stampa sta a soli 0.004 unità dalla mesh sottostante:
    // senza polygon offset le due superfici litigano per lo stesso pixel
    // (z-fighting) a seconda dell'angolo di vista.
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1,
  });
  const map = new TextureLoader().load(printUrl, onReady);
  map.colorSpace = SRGBColorSpace;
  material.map = map;

  const mesh = new Mesh(geometry, material);
  mesh.position.set(instanceX, y, 0);
  return mesh;
};

export default function Avatar3D({ config, outfit, textures, height = 420, onUnavailable }) {
  const mountRef = useRef(null);
  const stateRef = useRef({});

  // Chiamata sempre aggiornata dentro l'effect di mount (dipendenze vuote
  // apposta, vedi sotto): una ref evita di dover ricreare la scena ogni volta
  // che il genitore passa una nuova funzione onUnavailable.
  const onUnavailableRef = useRef(onUnavailable);
  useEffect(() => {
    onUnavailableRef.current = onUnavailable;
  }, [onUnavailable]);

  // La scena (renderer, camera, luci, gruppo figura) si crea una volta sola,
  // al mount. Un `height` che cambia non deve distruggerla: altrimenti corpo
  // e capi, ricostruiti solo dall'altro effect, sparirebbero dalla scena
  // nuova finché config/outfit/textures non cambiano di nuovo.
  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return undefined;

    // La creazione del renderer può lanciare (memoria satura, troppi context
    // GL vivi sul browser mobile...). Senza try/catch l'eccezione risale non
    // gestita: React smonta l'intero albero e la pagina resta bianca, senza
    // che nessuno spieghi perché. Qui si avvisa il genitore e si esce senza
    // costruire nient'altro: niente da ripulire, non è mai stato agganciato.
    let renderer;
    try {
      renderer = new WebGLRenderer({ antialias: true, alpha: true });
    } catch (err) {
      onUnavailableRef.current?.(err);
      return undefined;
    }

    const scene = new Scene();
    const camera = new PerspectiveCamera(32, 0.5, 0.1, 100);
    camera.position.set(0, 0.95, 5.2);
    camera.lookAt(0, 0.9, 0);

    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(height / 2, height);
    mount.appendChild(renderer.domElement);

    // Luci più contrastate: senza ombre proiettate (costerebbero un
    // renderer.shadowMap e un ciclo di aggiornamento in più), il contatto a
    // terra lo dà solo il cerchio d'ombra sotto i piedi.
    scene.add(new AmbientLight(0xffffff, 1.1));
    const key = new DirectionalLight(0xffffff, 2.0);
    key.position.set(2, 4, 3);
    scene.add(key);
    const rim = new DirectionalLight(0xffffff, 0.7);
    rim.position.set(-3, 2, -2);
    scene.add(rim);

    const figure = new Group();
    scene.add(figure);

    const state = stateRef.current;
    state.unmounted = false;
    // Guardia contro la corsa asincrona della texture: se lo smontaggio
    // arriva prima che l'immagine sia pronta, il suo onReady (= render) non
    // deve disegnare su un renderer già disposato.
    const render = () => {
      if (state.unmounted) return;
      renderer.render(scene, camera);
    };
    Object.assign(state, { scene, camera, renderer, figure, render });

    // Rotazione al trascinamento: si ridisegna solo mentre il dito si muove.
    let dragging = false;
    let lastX = 0;
    const onDown = (e) => {
      dragging = true;
      lastX = e.clientX;
      renderer.domElement.setPointerCapture(e.pointerId);
    };
    const onMove = (e) => {
      if (!dragging) return;
      figure.rotation.y += (e.clientX - lastX) * 0.01;
      lastX = e.clientX;
      render();
    };
    const onUp = () => {
      dragging = false;
    };
    renderer.domElement.addEventListener('pointerdown', onDown);
    renderer.domElement.addEventListener('pointermove', onMove);
    renderer.domElement.addEventListener('pointerup', onUp);
    renderer.domElement.addEventListener('pointercancel', onUp);
    renderer.domElement.style.touchAction = 'none';
    renderer.domElement.style.cursor = 'grab';

    // Il context GL può sparire a metà sessione (memoria recuperata dal
    // sistema, telefonata in arrivo su Android...) senza che il componente si
    // smonti: la scena resta nera e ferma. `hasWebGL()` non se ne accorge
    // perché è cache-ata alla prima chiamata. Qui si intercetta l'evento e si
    // avvisa il genitore, che passa alla modalità piatta.
    const onContextLost = (e) => {
      e.preventDefault();
      onUnavailableRef.current?.(e);
    };
    renderer.domElement.addEventListener('webglcontextlost', onContextLost);

    return () => {
      state.unmounted = true;
      renderer.domElement.removeEventListener('pointerdown', onDown);
      renderer.domElement.removeEventListener('pointermove', onMove);
      renderer.domElement.removeEventListener('pointerup', onUp);
      renderer.domElement.removeEventListener('pointercancel', onUp);
      renderer.domElement.removeEventListener('webglcontextlost', onContextLost);
      // Libera geometrie, materiali e texture di corpo/capi/decal prima di
      // disporre il renderer: altrimenti restano risorse GPU orfane.
      clearFigure(figure);
      renderer.dispose();
      mount.removeChild(renderer.domElement);
    };
    // Dipendenze vuote apposta: la scena si crea una sola volta. Il resize
    // vive nel prossimo effect, la ricostruzione di corpo/capi in quello dopo.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Ridimensionamento: non distrugge né ricrea nulla, aggiorna solo renderer
  // e camera esistenti e ridisegna la figura già in scena.
  useEffect(() => {
    const { renderer, camera, render } = stateRef.current;
    if (!renderer || !camera) return;

    const width = height / 2;
    renderer.setSize(width, height);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    render?.();
  }, [height]);

  // Corpo e capi si ricostruiscono quando cambia la configurazione o l'outfit.
  useEffect(() => {
    const { figure, render } = stateRef.current;
    if (!figure) return;

    clearFigure(figure);

    const body = bodyProfiles(config);
    const skin = new MeshStandardMaterial({ color: new Color(body.skinHex), roughness: 0.85 });
    const hair = new MeshStandardMaterial({ color: new Color(body.hairHex), roughness: 0.95 });

    // Ombra a terra: non è un'ombra vera (nessuna luce coinvolta, nessun
    // ombra proiettata da calcolare), solo un cerchio scuro e trasparente
    // sotto i piedi. Toglie l'effetto "figura che galleggia" a costo zero.
    const shadowRadius = body.legOffsetX + Math.max(...body.leg.map(([r]) => r)) * 1.8;
    const shadow = new Mesh(
      new CircleGeometry(shadowRadius, 24),
      new MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.18 })
    );
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.002;
    figure.add(shadow);

    figure.add(new Mesh(lathe(body.torso), skin));
    for (const sign of [-1, 1]) {
      const leg = new Mesh(lathe(body.leg), skin);
      leg.position.x = sign * body.legOffsetX;
      figure.add(leg);
      const arm = new Mesh(lathe(body.arm), skin);
      arm.position.x = sign * body.armOffsetX;
      figure.add(arm);
    }

    const head = new Mesh(new SphereGeometry(body.head.radius, 24, 18), skin);
    head.position.y = body.head.y;
    head.scale.set(0.92, 1.12, 0.95);
    figure.add(head);

    if (body.hairStyle !== 'bald') {
      const cap = new Mesh(new SphereGeometry(body.head.radius * 1.06, 24, 18), hair);
      cap.position.y = body.head.y + 0.02;
      cap.scale.set(0.95, 1.0, 0.98);
      figure.add(cap);
    }

    for (const { kind, item } of garmentLayers(outfit)) {
      const parts = garmentParts(kind, config);
      if (!parts.length) continue;

      const texture = textures?.[item.id];
      // Un solo materiale per capo: busto e maniche sono lo stesso tessuto,
      // non due foto diverse.
      const material = garmentMaterial(texture, render);

      for (const part of parts) {
        const xs = part.mirror ? [-part.offsetX, part.offsetX] : [0];
        for (const dx of xs) {
          const mesh = new Mesh(lathe(part.profile), material);
          mesh.position.x = dx;
          figure.add(mesh);
        }
      }

      // La stampa va sulla parte principale del capo (parts[0]), mai sulle
      // maniche: un logo sul taschino resta sul taschino.
      if (texture?.printUrl && texture?.printAt) {
        const decal = printDecal(parts[0], texture.printUrl, texture.printAt, render);
        if (decal) figure.add(decal);
      }
    }

    render();
  }, [config, outfit, textures]);

  return <div className="avatar3d" ref={mountRef} style={{ height }} aria-label="avatar 3D" />;
}
