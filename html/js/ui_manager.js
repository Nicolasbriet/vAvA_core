/**
 * vAvA_core - UI Manager JavaScript
 * Gère toutes les interfaces NUI
 * 
 * Fonctionnalités:
 * - Notifications
 * - Progress Bar
 * - Prompts/Confirmations
 * - Input
 * - HUD Updates
 */

// État global
const UIState = {
    currentNUI: null,
    notifications: [],
    progressActive: false,
    hudVisible: true
};

// Charte graphique vAvA
const vAvATheme = {
    primary: '#FF1E1E',      // Rouge néon
    primaryDark: '#8B0000',  // Rouge foncé
    background: '#000000',    // Noir profond
    text: '#FFFFFF',          // Blanc
    glow: '0 0 20px #FF1E1E'
};

// ═══════════════════════════════════════════════════════════════════════════
// SYSTÈME DE NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════

function showNotification(message, type, duration) {
    const notificationId = Date.now();
    
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.id = `notification-${notificationId}`;
    notification.innerHTML = `
        <div class="notification-icon">${getNotificationIcon(type)}</div>
        <div class="notification-content">
            <span class="notification-message">${message}</span>
        </div>
        <div class="notification-progress"></div>
    `;
    
    // Conteneur de notifications
    let container = document.getElementById('notifications-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'notifications-container';
        container.className = 'notifications-container';
        document.body.appendChild(container);
    }
    
    container.appendChild(notification);
    
    // Animation d'entrée
    setTimeout(() => {
        notification.classList.add('notification-show');
    }, 10);
    
    // Barre de progression
    const progressBar = notification.querySelector('.notification-progress');
    progressBar.style.animation = `notification-progress ${duration}ms linear`;
    
    // Suppression automatique
    setTimeout(() => {
        notification.classList.remove('notification-show');
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, duration);
}

function getNotificationIcon(type) {
    const icons = {
        info: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13,9H11V7H13M13,17H11V11H13M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z"/></svg>',
        success: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22A10,10 0 0,1 2,12A10,10 0 0,1 12,2M11,16.5L18,9.5L16.59,8.09L11,13.67L7.91,10.59L6.5,12L11,16.5Z"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12,2L1,21H23M12,6L19.53,19H4.47M11,10V14H13V10M11,16V18H13V16"/></svg>',
        error: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12,2C17.53,2 22,6.47 22,12C22,17.53 17.53,22 12,22C6.47,22 2,17.53 2,12C2,6.47 6.47,2 12,2M15.59,7L12,10.59L8.41,7L7,8.41L10.59,12L7,15.59L8.41,17L12,13.41L15.59,17L17,15.59L13.41,12L17,8.41L15.59,7Z"/></svg>'
    };
    return icons[type] || icons.info;
}

// ═══════════════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════

function showProgressBar(label, duration, color) {
    if (UIState.progressActive) return;
    
    UIState.progressActive = true;
    
    const progressContainer = document.createElement('div');
    progressContainer.id = 'progress-bar-container';
    progressContainer.className = 'progress-bar-container';
    progressContainer.innerHTML = `
        <div class="progress-bar-box">
            <div class="progress-bar-label">${label}</div>
            <div class="progress-bar-track">
                <div class="progress-bar-fill" id="progress-bar-fill"></div>
            </div>
            <div class="progress-bar-hint">Appuyez sur [X] pour annuler</div>
        </div>
    `;
    
    document.body.appendChild(progressContainer);
    
    // Animation de la barre
    const fill = document.getElementById('progress-bar-fill');
    fill.style.backgroundColor = color || vAvATheme.primary;
    fill.style.boxShadow = `0 0 15px ${color || vAvATheme.primary}`;
    fill.style.transition = `width ${duration}ms linear`;
    
    setTimeout(() => {
        fill.style.width = '100%';
    }, 50);
}

function hideProgressBar() {
    const container = document.getElementById('progress-bar-container');
    if (container) {
        container.classList.add('progress-bar-hide');
        setTimeout(() => {
            if (container.parentNode) {
                container.parentNode.removeChild(container);
            }
        }, 300);
    }
    UIState.progressActive = false;
}

// ═══════════════════════════════════════════════════════════════════════════
// PROMPT / CONFIRMATION
// ═══════════════════════════════════════════════════════════════════════════

function showPrompt(title, message, confirmText, cancelText, color) {
    const promptContainer = document.createElement('div');
    promptContainer.id = 'prompt-container';
    promptContainer.className = 'prompt-container';
    promptContainer.innerHTML = `
        <div class="prompt-overlay"></div>
        <div class="prompt-box">
            <div class="prompt-title">${title}</div>
            <div class="prompt-message">${message}</div>
            <div class="prompt-buttons">
                <button class="prompt-btn prompt-btn-cancel" id="prompt-cancel">${cancelText}</button>
                <button class="prompt-btn prompt-btn-confirm" id="prompt-confirm" style="background: ${color}; box-shadow: 0 0 15px ${color};">${confirmText}</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(promptContainer);
    
    // Événements
    document.getElementById('prompt-confirm').addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/promptConfirm`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({})
        });
        closePrompt();
    });
    
    document.getElementById('prompt-cancel').addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/promptCancel`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({})
        });
        closePrompt();
    });
}

function closePrompt() {
    const container = document.getElementById('prompt-container');
    if (container) {
        container.classList.add('prompt-hide');
        setTimeout(() => {
            if (container.parentNode) {
                container.parentNode.removeChild(container);
            }
        }, 300);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// INPUT
// ═══════════════════════════════════════════════════════════════════════════

function showInput(title, placeholder, maxLength, color) {
    const inputContainer = document.createElement('div');
    inputContainer.id = 'input-container';
    inputContainer.className = 'input-container';
    inputContainer.innerHTML = `
        <div class="input-overlay"></div>
        <div class="input-box">
            <div class="input-title">${title}</div>
            <input type="text" class="input-field" id="input-field" placeholder="${placeholder}" maxlength="${maxLength}">
            <div class="input-buttons">
                <button class="input-btn input-btn-cancel" id="input-cancel">Annuler</button>
                <button class="input-btn input-btn-submit" id="input-submit" style="background: ${color}; box-shadow: 0 0 15px ${color};">Valider</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(inputContainer);
    
    const inputField = document.getElementById('input-field');
    inputField.focus();
    
    // Événements
    document.getElementById('input-submit').addEventListener('click', () => {
        const value = inputField.value.trim();
        fetch(`https://${GetParentResourceName()}/inputSubmit`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({value: value})
        });
        closeInput();
    });
    
    document.getElementById('input-cancel').addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/inputCancel`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({})
        });
        closeInput();
    });
    
    // Enter pour valider
    inputField.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            document.getElementById('input-submit').click();
        }
    });
}

function closeInput() {
    const container = document.getElementById('input-container');
    if (container) {
        container.classList.add('input-hide');
        setTimeout(() => {
            if (container.parentNode) {
                container.parentNode.removeChild(container);
            }
        }, 300);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// HUD
// ═══════════════════════════════════════════════════════════════════════════

function updateHUD(data) {
    // Mettre à jour santé
    if (data.health !== undefined) {
        const healthFill = document.getElementById('health-fill');
        const healthValue = document.getElementById('health-value');
        if (healthFill) healthFill.style.width = `${data.health}%`;
        if (healthValue) healthValue.textContent = Math.floor(data.health);
    }
    
    // Mettre à jour armure
    if (data.armor !== undefined) {
        const armorFill = document.getElementById('armor-fill');
        const armorValue = document.getElementById('armor-value');
        if (armorFill) armorFill.style.width = `${data.armor}%`;
        if (armorValue) armorValue.textContent = Math.floor(data.armor);
        
        // Afficher/cacher la barre d'armure
        const armorBar = document.getElementById('armor-bar');
        if (armorBar) {
            armorBar.style.display = data.armor > 0 ? 'flex' : 'none';
        }
    }
    
    // Mettre à jour faim
    if (data.hunger !== undefined) {
        const hungerFill = document.getElementById('hunger-fill');
        if (hungerFill) hungerFill.style.width = `${data.hunger}%`;
    }
    
    // Mettre à jour soif
    if (data.thirst !== undefined) {
        const thirstFill = document.getElementById('thirst-fill');
        if (thirstFill) thirstFill.style.width = `${data.thirst}%`;
    }
    
    // Mettre à jour argent
    if (data.money !== undefined) {
        const moneyValue = document.getElementById('money-value');
        if (moneyValue) moneyValue.textContent = formatMoney(data.money);
    }
}

function showHUD(components) {
    UIState.hudVisible = true;
    const hud = document.getElementById('status-hud');
    if (hud) hud.style.display = 'block';
}

function hideHUD(components) {
    UIState.hudVisible = false;
    const hud = document.getElementById('status-hud');
    if (hud) hud.style.display = 'none';
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

function formatMoney(amount) {
    return new Intl.NumberFormat('fr-FR', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 0
    }).format(amount);
}

function GetParentResourceName() {
    return window.location.hostname === '' ? 'vAvA_core' : window.GetParentResourceName();
}

// ═══════════════════════════════════════════════════════════════════════════
// GESTIONNAIRE DE MESSAGES
// ═══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.action) {
        case 'notify':
            showNotification(data.message, data.type, data.duration);
            break;
            
        case 'showProgress':
            showProgressBar(data.label, data.duration, data.color);
            break;
            
        case 'hideProgress':
            hideProgressBar();
            break;
            
        case 'showPrompt':
            showPrompt(data.title, data.message, data.confirmText, data.cancelText, data.color);
            break;
            
        case 'showInput':
            showInput(data.title, data.placeholder, data.maxLength, data.color);
            break;
            
        case 'updateHUD':
            updateHUD(data.data);
            break;
            
        case 'showHUD':
            showHUD(data.components);
            break;
            
        case 'hideHUD':
            hideHUD(data.components);
            break;
            
        case 'show':
            UIState.currentNUI = data.nui;
            showNUI(data.nui, data.data);
            break;
            
        case 'hide':
            if (UIState.currentNUI === data.nui) {
                UIState.currentNUI = null;
            }
            hideNUI(data.nui);
            break;
    }
});

// Fermer avec ESC
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (document.getElementById('prompt-container')) {
            document.getElementById('prompt-cancel').click();
        } else if (document.getElementById('input-container')) {
            document.getElementById('input-cancel').click();
        } else if (UIState.currentNUI) {
            fetch(`https://${GetParentResourceName()}/closeNUI`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({nui: UIState.currentNUI})
            });
        }
    }
});

// Initialisation
document.addEventListener('DOMContentLoaded', () => {
    console.log('[vAvA Core] UI Manager JS chargé');
});
