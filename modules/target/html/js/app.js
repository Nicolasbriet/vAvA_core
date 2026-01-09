// ============================================
// vAvA Target - JavaScript NUI
// ============================================

let currentMenu = null;
let currentOptions = [];
let selectedIndex = 0;

// ============================================
// GESTION DES MESSAGES NUI
// ============================================

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.action) {
        case 'open':
            openMenu(data);
            break;
        case 'close':
            closeMenu();
            break;
        case 'update':
            updateOptions(data.options);
            break;
        case 'disable':
            disableMenu();
            break;
        case 'enable':
            enableMenu();
            break;
    }
});

// ============================================
// OUVERTURE DU MENU
// ============================================

function openMenu(data) {
    currentOptions = data.options || [];
    selectedIndex = 0;
    
    // Déterminer le type de menu
    const menuType = data.menuType || 'radial';
    
    // Cacher tous les menus
    hideAllMenus();
    
    // Afficher le bon menu
    if (menuType === 'radial') {
        showRadialMenu(data);
    } else if (menuType === 'list') {
        showListMenu(data);
    } else if (menuType === 'compact') {
        showCompactMenu(data);
    }
    
    // Afficher distance si activé
    if (data.showDistance && data.distance !== undefined) {
        showDistance(data.distance);
    }
    
    // Ajouter animations
    if (data.animationDuration) {
        currentMenu.style.animationDuration = `${data.animationDuration}ms`;
    }
}

// ============================================
// MENU RADIAL
// ============================================

function showRadialMenu(data) {
    const menu = document.getElementById('radial-menu');
    const optionsContainer = document.getElementById('radial-options');
    
    // Vider le conteneur
    optionsContainer.innerHTML = '';
    
    // Calculer positions
    const angleStep = (2 * Math.PI) / currentOptions.length;
    const radius = 150; // Distance du centre
    
    currentOptions.forEach((option, index) => {
        const angle = angleStep * index - Math.PI / 2; // Commencer en haut
        
        const x = Math.cos(angle) * radius + 200; // 200 = centre du menu (400/2)
        const y = Math.sin(angle) * radius + 200;
        
        const optionDiv = document.createElement('div');
        optionDiv.className = 'radial-option';
        optionDiv.style.left = `${x - 50}px`; // -50 pour centrer (100/2)
        optionDiv.style.top = `${y - 50}px`;
        optionDiv.style.animationDelay = `${index * 0.05}s`;
        
        // Icône
        const icon = document.createElement('i');
        icon.className = option.icon || 'fa-solid fa-circle';
        
        // Label
        const label = document.createElement('div');
        label.className = 'label';
        label.textContent = option.label || 'Action';
        
        optionDiv.appendChild(icon);
        optionDiv.appendChild(label);
        
        // Event listener
        optionDiv.addEventListener('click', () => selectOption(index));
        
        optionsContainer.appendChild(optionDiv);
    });
    
    // Afficher le menu
    menu.style.display = 'block';
    setTimeout(() => menu.classList.add('active', 'fade-in'), 10);
    
    currentMenu = menu;
}

// ============================================
// MENU LISTE
// ============================================

function showListMenu(data) {
    const menu = document.getElementById('list-menu');
    const optionsContainer = document.getElementById('list-options');
    
    // Vider le conteneur
    optionsContainer.innerHTML = '';
    
    // Position
    menu.className = 'menu-container list-menu';
    if (data.position) {
        menu.classList.add(data.position);
    }
    
    currentOptions.forEach((option, index) => {
        const optionDiv = document.createElement('div');
        optionDiv.className = 'list-option';
        optionDiv.style.animationDelay = `${index * 0.05}s`;
        
        // Icône
        const icon = document.createElement('i');
        icon.className = option.icon || 'fa-solid fa-circle';
        
        // Contenu
        const content = document.createElement('div');
        content.className = 'content';
        
        const label = document.createElement('div');
        label.className = 'label';
        label.textContent = option.label || 'Action';
        
        content.appendChild(label);
        
        // Keybind (optionnel)
        if (data.showKeybind && option.keybind) {
            const keybind = document.createElement('div');
            keybind.className = 'keybind';
            keybind.textContent = `[${option.keybind}]`;
            content.appendChild(keybind);
        }
        
        optionDiv.appendChild(icon);
        optionDiv.appendChild(content);
        
        // Event listener
        optionDiv.addEventListener('click', () => selectOption(index));
        
        optionsContainer.appendChild(optionDiv);
    });
    
    // Afficher le menu
    menu.style.display = 'block';
    setTimeout(() => menu.classList.add('active', 'fade-in'), 10);
    
    currentMenu = menu;
}

// ============================================
// MENU COMPACT
// ============================================

function showCompactMenu(data) {
    const menu = document.getElementById('compact-menu');
    const optionsContainer = document.getElementById('compact-options');
    
    // Vider le conteneur
    optionsContainer.innerHTML = '';
    
    currentOptions.forEach((option, index) => {
        const optionDiv = document.createElement('div');
        optionDiv.className = 'compact-option';
        optionDiv.style.animationDelay = `${index * 0.05}s`;
        
        // Icône
        const icon = document.createElement('i');
        icon.className = option.icon || 'fa-solid fa-circle';
        
        // Label
        const label = document.createElement('div');
        label.className = 'label';
        label.textContent = option.label || 'Action';
        
        optionDiv.appendChild(icon);
        optionDiv.appendChild(label);
        
        // Event listener
        optionDiv.addEventListener('click', () => selectOption(index));
        
        optionsContainer.appendChild(optionDiv);
    });
    
    // Afficher le menu
    menu.style.display = 'block';
    setTimeout(() => menu.classList.add('active', 'fade-in'), 10);
    
    currentMenu = menu;
}

// ============================================
// FERMETURE DU MENU
// ============================================

function closeMenu() {
    if (currentMenu) {
        currentMenu.classList.remove('fade-in');
        currentMenu.classList.add('fade-out');
        
        setTimeout(() => {
            currentMenu.classList.remove('active', 'fade-out');
            currentMenu.style.display = 'none';
            currentMenu = null;
        }, 300);
    }
    
    // Cacher distance
    hideDistance();
    
    currentOptions = [];
    selectedIndex = 0;
}

// ============================================
// CACHER TOUS LES MENUS
// ============================================

function hideAllMenus() {
    document.querySelectorAll('.menu-container').forEach(menu => {
        menu.classList.remove('active', 'fade-in', 'fade-out');
        menu.style.display = 'none';
    });
}

// ============================================
// SÉLECTION D'UNE OPTION
// ============================================

function selectOption(index) {
    if (index < 0 || index >= currentOptions.length) {
        return;
    }
    
    const option = currentOptions[index];
    
    // Envoyer au client Lua
    fetch(`https://${GetParentResourceName()}/selectOption`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            option: option,
            index: index
        })
    });
    
    // Fermer le menu
    closeMenu();
}

// ============================================
// MISE À JOUR DES OPTIONS
// ============================================

function updateOptions(options) {
    currentOptions = options || [];
    
    if (currentMenu) {
        // Re-render le menu actuel
        const menuId = currentMenu.id;
        
        if (menuId === 'radial-menu') {
            showRadialMenu({options: options, menuType: 'radial'});
        } else if (menuId === 'list-menu') {
            showListMenu({options: options, menuType: 'list'});
        } else if (menuId === 'compact-menu') {
            showCompactMenu({options: options, menuType: 'compact'});
        }
    }
}

// ============================================
// AFFICHAGE DISTANCE
// ============================================

function showDistance(distance) {
    const indicator = document.getElementById('distance-indicator');
    const valueSpan = document.getElementById('distance-value');
    
    valueSpan.textContent = `${distance.toFixed(1)}m`;
    indicator.style.display = 'flex';
}

function hideDistance() {
    const indicator = document.getElementById('distance-indicator');
    indicator.style.display = 'none';
}

// ============================================
// DÉSACTIVER/ACTIVER
// ============================================

function disableMenu() {
    closeMenu();
    // Optionnel: ajouter une classe CSS pour indiquer que c'est désactivé
}

function enableMenu() {
    // Optionnel: retirer la classe CSS
}

// ============================================
// ÉVÉNEMENTS CLAVIER
// ============================================

document.addEventListener('keydown', (event) => {
    if (!currentMenu) {
        return;
    }
    
    switch (event.key) {
        case 'Escape':
            event.preventDefault();
            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
            break;
            
        case 'Enter':
            event.preventDefault();
            selectOption(selectedIndex);
            break;
            
        case 'ArrowUp':
            event.preventDefault();
            selectedIndex = Math.max(0, selectedIndex - 1);
            highlightOption(selectedIndex);
            break;
            
        case 'ArrowDown':
            event.preventDefault();
            selectedIndex = Math.min(currentOptions.length - 1, selectedIndex + 1);
            highlightOption(selectedIndex);
            break;
    }
});

// ============================================
// MISE EN SURBRILLANCE
// ============================================

function highlightOption(index) {
    // Retirer la surbrillance précédente
    document.querySelectorAll('.radial-option, .list-option, .compact-option').forEach(el => {
        el.classList.remove('highlighted');
    });
    
    // Ajouter la surbrillance
    const options = document.querySelectorAll('.radial-option, .list-option, .compact-option');
    if (options[index]) {
        options[index].classList.add('highlighted');
    }
}

// ============================================
// UTILITAIRES
// ============================================

function GetParentResourceName() {
    const url = window.location.href;
    const match = url.match(/https?:\/\/cfx-nui-([^\/]+)/);
    return match ? match[1] : 'vAvA_target';
}

// ============================================
// INITIALISATION
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('[vAvA Target] NUI initialized');
    
    // Cacher tous les menus au démarrage
    hideAllMenus();
});

// Empêcher le clic droit
document.addEventListener('contextmenu', (event) => {
    event.preventDefault();
});
