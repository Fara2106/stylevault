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
import { garmentParts } from '../../utils/garmentMesh';
import { garmentLayers } from '../../utils/tryonComposer';
import { panelPlacement } from '../../utils/garmentPanel';

const RADIAL_SEGMENTS = 32;
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

// Il pannello del capo: un arco di cilindro davanti al corpo, su cui si mappa
// il ritaglio del capo. L'arco massimo lascia spazio al profilo (la stampa gira
// col corpo). Il raggio e l'ampiezza reali li calcola panelPlacement.
const PANEL_ARC = (150 * Math.PI) / 180;
const PANEL_GAP = 0.02;
const PANEL_RADIAL_SEGMENTS = 24;

/** Un pannello (arco di cilindro) con sopra la texture del ritaglio. */
const garmentPanel = (placement, thetaStart, map) => {
  const geometry = new CylinderGeometry(
    placement.radius,
    placement.radius,
    Math.max(placement.height, 0.001),
    PANEL_RADIAL_SEGMENTS,
    1,
    true, // aperto: è un guscio d'arco, non un cilindro pieno
    thetaStart,
    placement.arcAngle
  );
  const material = new MeshStandardMaterial({
    map,
    transparent: true,
    side: DoubleSide,
    roughness: 0.9,
  });
  const mesh = new Mesh(geometry, material);
  mesh.position.y = placement.yCenter;
  return mesh;
};

/**
 * Carica il ritaglio del capo e, quando l'immagine è pronta (serve l'aspect
 * ratio), aggiunge un pannello davanti e uno dietro. `isCancelled` evita di
 * aggiungere mesh a una figura già ripulita da una ricostruzione successiva.
 */
const addGarmentPanels = (figure, mainPart, url, onRender, isCancelled) => {
  const map = new TextureLoader().load(url, () => {
    if (isCancelled()) {
      map.dispose();
      return;
    }
    const aspect = (map.image?.width || 1) / (map.image?.height || 1);
    const placement = panelPlacement({
      profile: mainPart.profile,
      offsetX: mainPart.offsetX,
      mirror: mainPart.mirror,
      aspect,
      arc: PANEL_ARC,
      gap: PANEL_GAP,
    });

    map.colorSpace = SRGBColorSpace;
    // Davanti, centrato sul fronte (+Z, come faceva il vecchio decal a theta 0).
    figure.add(garmentPanel(placement, -placement.arcAngle / 2, map));

    // Dietro: stessa immagine, ribaltata in orizzontale così non appare
    // speculare guardando la schiena.
    const back = map.clone();
    back.colorSpace = SRGBColorSpace;
    back.wrapS = RepeatWrapping;
    back.repeat.x = -1;
    back.needsUpdate = true;
    figure.add(garmentPanel(placement, Math.PI - placement.arcAngle / 2, back));

    onRender();
  });
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
    if (!figure) return undefined;

    let cancelled = false;
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

      if (texture?.textureUrl) {
        // Il capo intero ritagliato, messo sul corpo come un capo — non tilato.
        addGarmentPanels(
          figure,
          parts[0],
          texture.textureUrl,
          () => {
            if (!cancelled) render();
          },
          () => cancelled
        );
      } else {
        // Fallback: niente ritaglio (foto CORS o degradata) → tinta unita.
        const material = new MeshStandardMaterial({
          color: safeColor(texture?.colorHex),
          roughness: 0.95,
        });
        for (const part of parts) {
          const xs = part.mirror ? [-part.offsetX, part.offsetX] : [0];
          for (const dx of xs) {
            const mesh = new Mesh(lathe(part.profile), material);
            mesh.position.x = dx;
            figure.add(mesh);
          }
        }
      }
    }

    render();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [config, outfit, textures]);

  return <div className="avatar3d" ref={mountRef} style={{ height }} aria-label="avatar 3D" />;
}
