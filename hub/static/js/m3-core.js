// Ripple M3 - Core Interactions
document.addEventListener('mousedown', function (e) {
    const button = e.target.closest('.ripple-btn');
    if (button) {
        const rect = button.getBoundingClientRect();
        const circle = document.createElement('span');
        circle.classList.add('ripple');
        circle.style.left = `${e.clientX - rect.left}px`;
        circle.style.top = `${e.clientY - rect.top}px`;
        const diameter = Math.max(rect.width, rect.height);
        circle.style.width = circle.style.height = `${diameter}px`;
        circle.style.marginLeft = circle.style.marginTop = `${-diameter / 2}px`;
        
        // Efecto inverso para botones claros o transparentes
        if(button.classList.contains('btn-outlined') || 
           button.classList.contains('btn-tonal') || 
           button.classList.contains('standard') ||
           button.classList.contains('m3-chip')) {
            circle.style.backgroundColor = 'rgba(0, 0, 0, 0.1)';
        }
        
        button.appendChild(circle);
        
        // Eliminar del DOM despues de la animacion para no consumir RAM
        setTimeout(() => circle.remove(), 600);
    }
});

// --- MOTOR DE TEMAS M3 ---
function applyTheme(theme, color) {
    document.body.className = ''; // Reset
    if (theme === 'dark') document.body.classList.add('theme-dark');
    if (color && color !== 'warm') document.body.classList.add('color-' + color);
    
    localStorage.setItem('m3-theme', theme);
    localStorage.setItem('m3-color', color);
}

// Cargar tema guardado al iniciar
document.addEventListener('DOMContentLoaded', () => {
    const savedTheme = localStorage.getItem('m3-theme') || 'light';
    const savedColor = localStorage.getItem('m3-color') || 'warm';
    applyTheme(savedTheme, savedColor);
});
