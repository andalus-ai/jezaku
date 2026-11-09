const threeVersion = '0.160.0';
const threeBaseUrl = `https://cdn.jsdelivr.net/npm/three@${threeVersion}`;

const status = window.arEngineThreeBootstrap ?? {
  state: 'loading',
  version: threeVersion,
};
window.arEngineThreeBootstrap = status;

try {
  const [threeModule, gltfModule, objModule] = await Promise.all([
    import(`${threeBaseUrl}/build/three.module.js`),
    import(`${threeBaseUrl}/examples/jsm/loaders/GLTFLoader.js`),
    import(`${threeBaseUrl}/examples/jsm/loaders/OBJLoader.js`),
  ]);

  window.THREE = window.THREE ?? threeModule;
  window.THREE.GLTFLoader = window.THREE.GLTFLoader ?? gltfModule.GLTFLoader;
  window.THREE.OBJLoader = window.THREE.OBJLoader ?? objModule.OBJLoader;
  window.GLTFLoader = window.GLTFLoader ?? gltfModule.GLTFLoader;
  window.OBJLoader = window.OBJLoader ?? objModule.OBJLoader;

  status.state = 'ready';
} catch (error) {
  status.state = 'failed';
  status.error = error instanceof Error ? error.message : String(error);
  console.warn('ar_engine web Three.js bootstrap failed', error);
}
