import { useEffect, useRef } from 'react';
import {
  Scene,
  PerspectiveCamera,
  WebGLRenderer,
  LatheGeometry,
  CylinderGeometry,
  SphereGeometry,
  MeshStandardMaterial,
  Mesh,
  Group,
  Vector2,
  Color,
  AmbientLight,
  DirectionalLight,
  TextureLoader,
  DoubleSide,
  SRGBColorSpace,
} from 'three';
import { bodyProfiles } from '../../utils/avatarMesh';
import { garmentProfile, decalBounds } from '../../utils/garmentMesh';
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
 * Superficie curva sul davanti del capo, dove si applica la fantasia vera.
 * Serve anche ai capi sdoppiati (pantaloni, scarpe): senza, uscirebbero in
 * tinta unita e la fantasia si vedrebbe solo sulla metà superiore del corpo.
 */
const frontDecal = (profile, textureUrl, onReady, extraRadius = 0) => {
  const { top, bottom, radius, centerY } = decalBounds(profile, extraRadius);

  const geometry = new CylinderGeometry(
    radius,
    radius,
    top - bottom,
    24,
    1,
    true,
    -DECAL_ARC / 2,
    DECAL_ARC
  );
  const material = new MeshStandardMaterial({
    transparent: true,
    side: DoubleSide,
    roughness: 0.9,
    // Il cilindro del decal sta a soli 0.004 unità dalla mesh sottostante:
    // senza polygon offset le due superfici litigano per lo stesso pixel
    // (z-fighting) a seconda dell'angolo di vista.
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1,
  });
  const texture = new TextureLoader().load(textureUrl, onReady);
  texture.colorSpace = SRGBColorSpace;
  material.map = texture;

  const mesh = new Mesh(geometry, material);
  mesh.position.y = centerY;
  mesh.rotation.y = Math.PI; // il fronte guarda la camera
  return mesh;
};

export default function Avatar3D({ config, outfit, textures, height = 420 }) {
  const mountRef = useRef(null);
  const stateRef = useRef({});

  // La scena (renderer, camera, luci, gruppo figura) si crea una volta sola,
  // al mount. Un `height` che cambia non deve distruggerla: altrimenti corpo
  // e capi, ricostruiti solo dall'altro effect, sparirebbero dalla scena
  // nuova finché config/outfit/textures non cambiano di nuovo.
  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return undefined;

    const scene = new Scene();
    const camera = new PerspectiveCamera(32, 0.5, 0.1, 100);
    camera.position.set(0, 0.95, 5.2);
    camera.lookAt(0, 0.9, 0);

    const renderer = new WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(height / 2, height);
    mount.appendChild(renderer.domElement);

    scene.add(new AmbientLight(0xffffff, 1.5));
    const key = new DirectionalLight(0xffffff, 1.8);
    key.position.set(2, 4, 3);
    scene.add(key);
    const rim = new DirectionalLight(0xffffff, 0.5);
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

    return () => {
      state.unmounted = true;
      renderer.domElement.removeEventListener('pointerdown', onDown);
      renderer.domElement.removeEventListener('pointermove', onMove);
      renderer.domElement.removeEventListener('pointerup', onUp);
      renderer.domElement.removeEventListener('pointercancel', onUp);
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
      const shape = garmentProfile(kind, config);
      if (!shape) continue;
      const texture = textures?.[item.id];
      const color = safeColor(texture?.colorHex || FALLBACK_COLOR);
      const material = new MeshStandardMaterial({ color, roughness: 0.92 });

      const offsets = shape.doubled ? [-shape.offsetX, shape.offsetX] : [0];
      for (const dx of offsets) {
        const mesh = new Mesh(lathe(shape.profile), material);
        mesh.position.x = dx;
        figure.add(mesh);
      }

      // Una sola superficie per la fantasia, anche sui capi sdoppiati: un paio
      // di jeans è una foto sola che copre due gambe, non la stessa foto due
      // volte. Per i capi sdoppiati la superficie si allarga fino ad abbracciarle.
      if (texture?.textureUrl) {
        figure.add(
          frontDecal(shape.profile, texture.textureUrl, render, shape.offsetX)
        );
      }
    }

    render();
  }, [config, outfit, textures]);

  return <div className="avatar3d" ref={mountRef} style={{ height }} aria-label="avatar 3D" />;
}
