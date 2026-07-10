import { Component } from 'react';

/**
 * Rete di sicurezza per il ramo 3D: se qualcosa dentro Avatar3D lancia a
 * runtime (oltre ai casi già intercettati dentro Avatar3D stesso — creazione
 * del renderer, perdita del context), un errore non gestito smonterebbe
 * l'intero albero React e lascerebbe la pagina bianca. Un ErrorBoundary è
 * l'unico modo che React offre per intercettare un throw durante il render
 * dei figli (nessun hook equivalente esiste).
 *
 * Non importa three.js: Avatar3D.jsx resta l'unico file che lo fa.
 */
export default class Avatar3DBoundary extends Component {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error) {
    this.props.onUnavailable?.(error);
  }

  render() {
    // Il genitore, avvisato da onUnavailable, passa a renderMode = 'flat' e
    // smette di montare questo albero: qui basta non ripetere lo schermo
    // bianco nel breve istante prima di quel re-render.
    if (this.state.hasError) return null;
    return this.props.children;
  }
}
