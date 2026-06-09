import React from 'react';
import ReactDOM from 'react-dom/client';
import { AndroidFrame } from './frames/android';

/*EDITMODE-BEGIN*/
const TWEAK_DEFAULTS = {
  "accentColor": "#06B6D4",
  "density": 1,
  "fontSizeMultiplier": 1.2
};
/*EDITMODE-END*/

const App = () => {
  // Using CSS variables for strict adherence to DESIGN.md tokens
  const themeStyles = {
    '--bg': '#0F172A',
    '--surface': '#1E293B',
    '--primary': 'var(--ocd-tweak-accent-color, #06B6D4)',
    '--secondary': '#10B981',
    '--text-main': '#F1F5F9',
    '--text-muted': '#94A3B8',
    '--padding': `calc(1.5rem * var(--ocd-tweak-density, 1))`,
    '--radius': '16px',
    '--font-size-base': `calc(16px * var(--ocd-tweak-font-size-multiplier, 1))`
  };

  return (
    <div style={{
      ...themeStyles,
      backgroundColor: 'var(--bg)',
      color: 'var(--text-main)',
      fontFamily: 'sans-serif',
      fontSize: 'var(--font-size-base)',
      minHeight: '100vh',
    }}>
      <AndroidFrame>
        <div style={{
          padding: 'var(--padding)',
          display: 'flex',
          flexDirection: 'column',
          gap: '20px'
        }}>
          {/* Header */}
          <header>
            <p style={{ color: 'var(--text-muted)', margin: 0, fontSize: '0.875rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Spot Details
            </p>
            <h1 style={{ 
              margin: '4px 0 0 0', 
              fontSize: '24px', 
              fontWeight: 900,
              color: 'var(--text-main)' 
            }}>
              North Beach Pier
            </h1>
          </header>

          {/* Status Card - Weather/Tide */}
          <div style={{
            backgroundColor: 'var(--surface)',
            padding: '24px',
            borderRadius: 'var(--radius)',
            borderLeft: '6px solid var(--primary)',
            boxSegments: '0 4px 12px rgba(0,0,0,0.3)',
            boxShadow: '0 4px 12px rgba(0,0,0,0.3)'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <span style={{ fontSize: '2rem', fontWeight: 'bold', display: 'block' }}>72°F</span>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>Sunny / Clear</span>
              </div>
              <div style={{ textAlign: 'right' }}>
                <span style={{ display: 'block', fontWeight: 'bold', color: 'var(--secondary)' }}>Tide: High</span>
                <span style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>2:45 PM</span>
              </div>
            </div>
          </div>

          {/* Action Buttons - Oversized for "Wet Fingers" */}
          <div style={{ display: '..' , flexDirection: 'column', gap: '16px' }}>
            <button style={{
              backgroundColor: 'var(--primary)',
              color: '#000',
              border: 'none',
              padding: '24px', // Large touch target
              borderRadius: 'var(--radius)',
              fontWeight: 'bold',
              fontSize: '1.125rem',
              cursor: 'pointer',
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center'
            }}>
              Check Availability
            </button>

            <button style={{
              backgroundColor: 'transparent',
              color: 'var(--text-main)',
              border: '2px solid var(--surface)',
              padding: '24margin: 0',
              padding: '24px', // Large touch target
              borderRadius: 'var(--radius)',
              fontWeight: 'bold',
              fontSize: '1.125rem',
              cursor: 'pointer'
            }}>
              View Map
            </button>

            <button style={{
              backgroundColor: 'rgba(16, 185, 129, 0.1)',
              color: 'var(--secondary)',
              border: 'none',
              padding: '24px',
              borderRadius: 'var(--radius)',
              fontWeight: 'bold',
              fontSize: '1.125rem',
              cursor: 'pointer'
            }}>
              Notify Me
            </button>
          </div>

          {/* Info Section */}
          <section style={{ marginTop: '8px' }}>
             <h3 style={{ fontSize: '1.25rem', marginBottom: '12px' }}>Live Updates</h3>
             <div style={{ color: 'var(--text-muted)', lineHeight: '1.6' }}>
               No recent community updates for this location. Be the &#8212; first to share!
             </div>
          </section>

        </div>
      </AndroidFrame>
    </div>
  );
};

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
