/**
 * vAvA_chat - Application JavaScript
 * Module intégré à vAvA_core
 */

// ═══════════════════════════════════════════════════════════════════════════
// VARIABLES GLOBALES
// ═══════════════════════════════════════════════════════════════════════════

let isDragging = false;
let dragOffsetX = 0, dragOffsetY = 0;
let dragTarget = null;

const chatBox = document.getElementById('chatbox');
let chatOpen = false;
let commandHistory = [];
let historyIndex = -1;

const chatInput = document.getElementById('chat-input');
const messages = document.getElementById('messages');

let commandList = [];
let suggestionBox = null;
let suggestions = [];
let chatHideTimeout = null;

// Permissions utilisateur
window.chatUserPerms = {
    isStaff: false,
    job: '',
};

// ═══════════════════════════════════════════════════════════════════════════
// BOUTONS DE RACCOURCI
// ═══════════════════════════════════════════════════════════════════════════

let shortcutContainer = document.getElementById('chat-shortcuts');
if (!shortcutContainer) {
    shortcutContainer = document.createElement('div');
    shortcutContainer.id = 'chat-shortcuts';
    shortcutContainer.style.display = 'flex';
    shortcutContainer.style.gap = '8px';
    shortcutContainer.style.marginTop = '6px';
    shortcutContainer.style.justifyContent = 'flex-start';
    shortcutContainer.style.flexWrap = 'wrap';
    const inputContainer = document.getElementById('input-container');
    if (inputContainer && inputContainer.parentElement) {
        inputContainer.parentElement.insertBefore(shortcutContainer, inputContainer.nextSibling);
    }
}

function renderChatShortcuts() {
    const baseShortcuts = [
        { cmd: '/me', label: 'me', color: '#007bff' },
        { cmd: '/do', label: 'do', color: '#28a745' },
        { cmd: '/ooc', label: 'ooc', color: '#888' },
    ];
    
    const staffShortcut = { cmd: '/staff', label: 'staff', color: '#d9534f' };
    const policeShortcut = { cmd: '/police', label: 'police', color: '#0055ff' };
    const emsShortcut = { cmd: '/ems', label: 'ems', color: '#e83e8c' };

    let shortcuts = [...baseShortcuts];
    if (window.chatUserPerms.isStaff) shortcuts.push(staffShortcut);
    if (window.chatUserPerms.job === 'police') shortcuts.push(policeShortcut);
    if (window.chatUserPerms.job === 'ambulance') shortcuts.push(emsShortcut);

    shortcutContainer.innerHTML = '';
    shortcuts.forEach(s => {
        const btn = document.createElement('button');
        btn.textContent = s.cmd;
        btn.style.background = s.color;
        btn.style.color = '#fff';
        btn.style.border = 'none';
        btn.style.borderRadius = '4px';
        btn.style.padding = '4px 10px';
        btn.style.fontWeight = 'bold';
        btn.style.cursor = 'pointer';
        btn.onclick = function() {
            chatInput.value = s.cmd + ' ';
            chatInput.focus();
            updateSuggestions();
        };
        shortcutContainer.appendChild(btn);
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// GESTION DES ONGLETS
// ═══════════════════════════════════════════════════════════════════════════

let activeTab = 'default';
let tabTypesBase = [
    { type: 'default', label: 'Général' },
    { type: 'ooc', label: 'OOC' },
    { type: 'do', label: 'DO' },
    { type: 'me', label: 'ME' },
    { type: 'mp', label: 'MP' },
    { type: 'police', label: 'Police' },
    { type: 'ems', label: 'EMS' },
    { type: 'staff', label: 'Staff' }
];
let tabTypes = [...tabTypesBase];
let tabContainers = {};

let tabBar = document.getElementById('chat-tabs');
if (!tabBar) {
    tabBar = document.createElement('div');
    tabBar.id = 'chat-tabs';
    tabBar.style.display = 'flex';
    tabBar.style.gap = '8px';
    tabBar.style.marginBottom = '6px';
    tabBar.style.borderBottom = '1px solid #333';
    tabBar.style.paddingBottom = '2px';
}

let messagesTabsContainer = document.getElementById('messages-tabs-container');
if (!messagesTabsContainer) {
    messagesTabsContainer = document.createElement('div');
    messagesTabsContainer.id = 'messages-tabs-container';
    messagesTabsContainer.style.display = 'block';
    messagesTabsContainer.style.width = '100%';
    messagesTabsContainer.style.flex = '1 1 auto';
}

function renderTabsAndContainers() {
    tabBar.innerHTML = '';
    messagesTabsContainer.innerHTML = '';
    tabContainers = {};
    
    tabTypes.forEach(tab => {
        let container = document.createElement('ul');
        container.id = 'messages-' + tab.type;
        container.style.listStyle = 'none';
        container.style.margin = '0';
        container.style.padding = '0';
        container.style.display = 'none';
        container.style.maxHeight = '100%';
        container.style.overflowY = 'auto';
        container.addEventListener('wheel', function(e) {
            if (!chatOpen && !window.chatuiOpen) {
                e.preventDefault();
                this.scrollTop += e.deltaY;
            }
        });
        
        messagesTabsContainer.appendChild(container);
        tabContainers[tab.type] = container;
        
        let btn = document.createElement('button');
        btn.textContent = tab.label;
        btn.style.background = '#222';
        btn.style.color = '#fff';
        btn.style.border = 'none';
        btn.style.borderRadius = '4px 4px 0 0';
        btn.style.padding = '4px 12px';
        btn.style.cursor = 'pointer';
        btn.onclick = function() { switchTab(tab.type); };
        tabBar.appendChild(btn);
    });
    
    switchTab(activeTab);
}

function switchTab(type) {
    Object.keys(tabContainers).forEach(t => {
        tabContainers[t].style.display = (t === type) ? 'block' : 'none';
    });
    Array.from(tabBar.children).forEach((btn, idx) => {
        btn.style.background = (tabTypes[idx].type === type) ? '#444' : '#222';
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// SUGGESTIONS DE COMMANDES
// ═══════════════════════════════════════════════════════════════════════════

(function createSuggestionBox() {
    suggestionBox = document.createElement('div');
    suggestionBox.id = 'suggestion-box';
    suggestionBox.style.position = 'absolute';
    suggestionBox.style.bottom = '45px';
    suggestionBox.style.left = '10px';
    suggestionBox.style.background = 'rgba(30,30,30,0.6)';
    suggestionBox.style.backdropFilter = 'blur(5px)';
    suggestionBox.style.color = '#fff';
    suggestionBox.style.borderRadius = '4px';
    suggestionBox.style.padding = '4px 8px';
    suggestionBox.style.display = 'none';
    suggestionBox.style.zIndex = '1000';
    if (chatBox) chatBox.appendChild(suggestionBox);
})();

function updateSuggestions() {
    const val = chatInput.value;
    if (val.startsWith('/')) {
        suggestions = window.suggestionData
            ? window.suggestionData.filter(s => s.name.startsWith(val))
            : commandList.filter(cmd => cmd.startsWith(val)).map(cmd => ({name: cmd, help: ''}));
        updateSuggestionBox();
    } else {
        suggestions = [];
        updateSuggestionBox();
    }
}

function updateSuggestionBox() {
    if (suggestions.length > 0 && chatInput.value.startsWith('/')) {
        suggestionBox.innerHTML = '';
        suggestions.forEach((s) => {
            const div = document.createElement('div');
            div.innerHTML = `<b>${s.name}</b>` + (s.help ? ` <span style="color:#fff;font-size:12px;">${s.help}</span>` : '');
            div.style.padding = '2px 4px';
            div.style.background = 'rgba(0, 0, 0, 0.1)';
            suggestionBox.appendChild(div);
        });
        suggestionBox.style.display = 'block';
        suggestionBox.style.background = 'transparent';
        suggestionBox.style.backdropFilter = 'none';
    } else {
        suggestionBox.style.display = 'none';
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// GESTION DES MESSAGES
// ═══════════════════════════════════════════════════════════════════════════

function addMessage(data) {
    let type = (data.type || '').toString().trim().toLowerCase();
    let prefix = (data.prefix || '').toString().trim().toUpperCase();
    let tabType = 'default';
    
    if (prefix.includes('ME') || type === 'me') tabType = 'me';
    else if (prefix.includes('DO') || type === 'do') tabType = 'do';
    else if (prefix.includes('OOC') || type === 'ooc') tabType = 'ooc';
    else if (prefix.includes('MP') || type === 'mp') tabType = 'mp';
    else if (prefix.includes('POLICE') || type === 'police') tabType = 'police';
    else if (prefix.includes('EMS') || type === 'ems') tabType = 'ems';
    else if (prefix.includes('STAFF') || type === 'staff') tabType = 'staff';

    const createMessageElement = () => {
        const li = document.createElement('li');
        let bg = 'rgba(0, 0, 0, 0.1)';
        if (type === 'me') bg = 'rgba(0, 123, 255, 0.1)';
        if (type === 'do') bg = 'rgba(40, 167, 69, 0.1)';
        if (type === 'ooc') bg = 'rgba(120, 120, 120, 0.1)';
        if (type === 'staff') bg = 'rgba(217, 83, 79, 0.1)';

        const msgSpan = document.createElement('span');
        msgSpan.style.background = bg;
        msgSpan.style.backdropFilter = 'none';
        msgSpan.style.borderRadius = '7px';
        msgSpan.style.display = 'inline-block';
        msgSpan.style.margin = '2px 0';
        msgSpan.style.padding = '2px 8px';

        const message = data.msg.includes(data.prefix) ? data.msg.substring(data.prefix.length).trim() : data.msg;
        const prefixColor = data.color ? `rgb(${data.color.join(',')})` : '#fff';
        msgSpan.innerHTML = `<span style="color:${prefixColor};font-weight:bold;">${data.prefix}</span> ${message}`;

        if (type === 'mp' || tabType === 'mp') {
            const idMatch = data.msg.match(/\((\d+)\)/);
            if (idMatch && idMatch[1]) {
                const replyBtn = document.createElement('button');
                replyBtn.textContent = '↩️ Répondre';
                replyBtn.style.marginLeft = '8px';
                replyBtn.style.background = 'rgba(0,255,180,0.2)';
                replyBtn.style.border = 'none';
                replyBtn.style.borderRadius = '4px';
                replyBtn.style.padding = '2px 6px';
                replyBtn.style.color = 'rgb(0,255,180)';
                replyBtn.style.cursor = 'pointer';
                replyBtn.onclick = function() {
                    chatInput.value = `/mp ${idMatch[1]} `;
                    chatInput.focus();
                };
                msgSpan.appendChild(replyBtn);
            }
        }

        li.appendChild(msgSpan);
        return li;
    };

    // Ajouter dans l'onglet spécifique
    if (tabContainers[tabType]) {
        const specificMessage = createMessageElement();
        tabContainers[tabType].appendChild(specificMessage);
        while (tabContainers[tabType].children.length > 10) {
            tabContainers[tabType].removeChild(tabContainers[tabType].firstChild);
        }
        tabContainers[tabType].scrollTop = tabContainers[tabType].scrollHeight;
    }

    // Ajouter aussi dans l'onglet Général
    if (tabContainers['default'] && tabType !== 'default') {
        const generalMessage = createMessageElement();
        tabContainers['default'].appendChild(generalMessage);
        while (tabContainers['default'].children.length > 10) {
            tabContainers['default'].removeChild(tabContainers['default'].firstChild);
        }
        tabContainers['default'].scrollTop = tabContainers['default'].scrollHeight;
    }

    // Afficher le chat
    showChatBox();
    
    // Timer de disparition
    if (chatHideTimeout) clearTimeout(chatHideTimeout);
    if (!chatOpen && !window.chatuiOpen) {
        chatHideTimeout = setTimeout(() => {
            if (!window.chatuiOpen) hideChatBox();
        }, 5000);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTRÔLE DU CHAT
// ═══════════════════════════════════════════════════════════════════════════

function openChat() {
    showChatBox();
    chatInput.value = '';
    chatInput.style.display = 'block';
    shortcutContainer.style.display = 'flex';
    chatInput.focus();
    chatOpen = true;
    if (chatHideTimeout) { clearTimeout(chatHideTimeout); chatHideTimeout = null; }
}

function closeChat() {
    chatInput.blur();
    chatInput.style.display = 'none';
    shortcutContainer.style.display = 'none';
    chatOpen = false;
    if (chatHideTimeout) clearTimeout(chatHideTimeout);
    chatHideTimeout = setTimeout(() => {
        if (!window.chatuiOpen) hideChatBox();
    }, 5000);
}

function showChatBox() {
    if (chatBox) { 
        chatBox.style.opacity = '1'; 
        chatBox.style.pointerEvents = 'auto';
        if (chatHideTimeout) clearTimeout(chatHideTimeout);
    }
}

function hideChatBox() {
    if (chatBox) {
        chatBox.style.opacity = '0';
        chatBox.style.pointerEvents = 'none';
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// REDIMENSIONNEMENT
// ═══════════════════════════════════════════════════════════════════════════

const RESIZE_SIZE = 16;
const resizeHandles = [
    { name: 'nw', cursor: 'nwse-resize' },
    { name: 'ne', cursor: 'nesw-resize' },
    { name: 'sw', cursor: 'nesw-resize' },
    { name: 'se', cursor: 'nwse-resize' }
];
let isResizing = false;
let resizeDir = null;
let resizeStart = { x: 0, y: 0, w: 0, h: 0, left: 0, top: 0 };

if (chatBox) {
    resizeHandles.forEach(handle => {
        const el = document.createElement('div');
        el.className = 'chatbox-resize-handle chatbox-resize-' + handle.name;
        el.addEventListener('mousedown', function(e) {
            if (!chatOpen) return;
            isResizing = true;
            resizeDir = handle.name;
            const rect = chatBox.getBoundingClientRect();
            resizeStart = { x: e.clientX, y: e.clientY, w: rect.width, h: rect.height, left: rect.left, top: rect.top };
            document.body.style.userSelect = 'none';
            e.stopPropagation();
            e.preventDefault();
        });
        chatBox.appendChild(el);
    });
}

function updateFontSize(width) {
    if (!chatBox) return;
    const baseFontSize = 14;
    const minFontSize = 10;
    const maxFontSize = 40;
    const scaleFactor = width / 300;
    let newSize = Math.floor(baseFontSize * scaleFactor);
    newSize = Math.max(minFontSize, Math.min(maxFontSize, newSize));
    
    chatBox.style.fontSize = `${newSize}px`;
    if (chatInput) chatInput.style.fontSize = `${newSize}px`;
    if (suggestionBox) suggestionBox.style.fontSize = `${newSize}px`;
    if (shortcutContainer) shortcutContainer.style.fontSize = `${Math.max(minFontSize, newSize * 0.9)}px`;
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉVÉNEMENTS GLOBAUX
// ═══════════════════════════════════════════════════════════════════════════

window.addEventListener('mousemove', function(e) {
    if (isDragging && chatOpen && dragTarget === chatBox) {
        const winW = window.innerWidth, winH = window.innerHeight;
        const boxW = dragTarget.offsetWidth, boxH = dragTarget.offsetHeight;
        let left = e.clientX - dragOffsetX, top = e.clientY - dragOffsetY;
        left = Math.max(0, Math.min(left, winW - boxW));
        top = Math.max(0, Math.min(top, winH - boxH));
        let leftPct = (left / winW) * 100, topPct = (top / winH) * 100;
        dragTarget.style.position = 'fixed';
        dragTarget.style.left = leftPct + '%';
        dragTarget.style.top = topPct + '%';
        dragTarget.style.right = '';
        dragTarget.style.bottom = '';
        
        let prefs = JSON.parse(localStorage.getItem('vava_chatui') || '{}');
        prefs.customPosChat = { left: leftPct, top: topPct };
        localStorage.setItem('vava_chatui', JSON.stringify(prefs));
    } else if (isResizing && chatOpen && chatBox) {
        const winW = window.innerWidth * 1.5;
        const winH = window.innerHeight;
        let dx = e.clientX - resizeStart.x, dy = e.clientY - resizeStart.y;
        let newW = resizeStart.w, newH = resizeStart.h, newLeft = resizeStart.left, newTop = resizeStart.top;
        
        if (resizeDir === 'se') { newW = Math.max(300, resizeStart.w + dx); newH = Math.max(120, resizeStart.h + dy); }
        else if (resizeDir === 'sw') { newW = Math.max(300, resizeStart.w - dx); newH = Math.max(120, resizeStart.h + dy); newLeft = resizeStart.left + dx; }
        else if (resizeDir === 'ne') { newW = Math.max(300, resizeStart.w + dx); newH = Math.max(120, resizeStart.h - dy); newTop = resizeStart.top + dy; }
        else if (resizeDir === 'nw') { newW = Math.max(300, resizeStart.w - dx); newH = Math.max(120, resizeStart.h - dy); newLeft = resizeStart.left + dx; newTop = resizeStart.top + dy; }
        
        newW = Math.min(newW, winW);
        newH = Math.min(newH, winH - 10);
        
        chatBox.style.width = newW + 'px';
        chatBox.style.height = newH + 'px';
        chatBox.style.position = 'fixed';
        chatBox.style.left = (newLeft / winW * 100) + '%';
        chatBox.style.top = (newTop / winH * 100) + '%';
        
        updateFontSize(newW);
        
        let prefs = JSON.parse(localStorage.getItem('vava_chatui') || '{}');
        prefs.customSizeChat = { width: newW, height: newH };
        prefs.customPosChat = { left: (newLeft / winW * 100), top: (newTop / winH * 100) };
        localStorage.setItem('vava_chatui', JSON.stringify(prefs));
    }
});

window.addEventListener('mouseup', function() {
    if (isDragging) { isDragging = false; dragTarget = null; document.body.style.userSelect = ''; }
    else if (isResizing) { isResizing = false; resizeDir = null; document.body.style.userSelect = ''; }
});

// ═══════════════════════════════════════════════════════════════════════════
// CLAVIER
// ═══════════════════════════════════════════════════════════════════════════

document.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' && chatOpen) {
        const messageToSend = chatInput.value;
        if (messageToSend.trim() !== '') {
            if (!messageToSend.trim().startsWith('/')) {
                chatInput.value = '';
                closeChat();
                fetch(`https://${GetParentResourceName()}/setNuiFocus`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ focus: false, cursor: false })
                });
                e.preventDefault();
                return;
            }
            
            commandHistory.unshift(messageToSend);
            if (commandHistory.length > 20) commandHistory.length = 20;
            historyIndex = -1;
            
            fetch(`https://${GetParentResourceName()}/chatMessage`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ msg: messageToSend })
            });
            chatInput.value = '';
        }
        closeChat();
        fetch(`https://${GetParentResourceName()}/setNuiFocus`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ focus: false, cursor: false })
        });
        e.preventDefault();
    } else if (e.key === 'ArrowUp' && chatOpen) {
        if (commandHistory.length > 0) {
            historyIndex = Math.min(historyIndex + 1, commandHistory.length - 1);
            chatInput.value = commandHistory[historyIndex];
            setTimeout(() => chatInput.setSelectionRange(chatInput.value.length, chatInput.value.length), 0);
        }
        e.preventDefault();
    } else if (e.key === 'ArrowDown' && chatOpen) {
        if (historyIndex > 0) {
            historyIndex--;
            chatInput.value = commandHistory[historyIndex];
        } else if (historyIndex === 0) {
            historyIndex = -1;
            chatInput.value = '';
        }
        setTimeout(() => chatInput.setSelectionRange(chatInput.value.length, chatInput.value.length), 0);
        e.preventDefault();
    } else if (e.key === 'Escape' && chatOpen) {
        closeChat();
        fetch(`https://${GetParentResourceName()}/closeChat`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        e.preventDefault();
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// NUI MESSAGES
// ═══════════════════════════════════════════════════════════════════════════

window.suggestionData = [];

window.addEventListener('message', function(event) {
    const data = event.data || {};
    
    switch (data.type) {
        case 'updateChatPerms':
            window.chatUserPerms = data.perms;
            renderChatShortcuts();
            
            let newTabTypes = tabTypesBase.filter(tab => {
                if (tab.type === 'police') return window.chatUserPerms.job === 'police';
                if (tab.type === 'ems') return window.chatUserPerms.job === 'ambulance';
                if (tab.type === 'staff') return window.chatUserPerms.isStaff;
                return true;
            });
            
            if (JSON.stringify(tabTypes) !== JSON.stringify(newTabTypes)) {
                tabTypes = newTabTypes;
                renderTabsAndContainers();
            }
            break;
            
        case 'updateSuggestions':
            window.suggestionData = data.suggestions;
            commandList = data.suggestions.map(s => s.name);
            break;
            
        case 'showMessage':
            addMessage(data);
            break;
            
        case 'openChat':
            openChat();
            break;
            
        case 'closeChat':
            closeChat();
            break;
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// INITIALISATION
// ═══════════════════════════════════════════════════════════════════════════

if (chatInput) {
    chatInput.addEventListener('input', function() { updateSuggestions(); });
}

window.addEventListener('DOMContentLoaded', function() {
    if (chatBox) {
        chatBox.addEventListener('mousedown', function(e) {
            if (chatOpen) {
                isDragging = true;
                dragTarget = chatBox;
                const rect = chatBox.getBoundingClientRect();
                dragOffsetX = e.clientX - rect.left;
                dragOffsetY = e.clientY - rect.top;
                document.body.style.userSelect = 'none';
            }
        });
    }

    const inputContainer = document.getElementById('input-container');
    if (inputContainer && inputContainer.parentElement) {
        inputContainer.parentElement.insertBefore(tabBar, inputContainer);
        inputContainer.parentElement.insertBefore(messagesTabsContainer, inputContainer);
    }

    // Appliquer les préférences sauvegardées
    const prefs = JSON.parse(localStorage.getItem('vava_chatui') || '{}');
    if (chatBox && prefs.customPosChat) {
        chatBox.style.position = 'fixed';
        chatBox.style.left = prefs.customPosChat.left + '%';
        chatBox.style.top = prefs.customPosChat.top + '%';
    }
    if (chatBox && prefs.customSizeChat) {
        chatBox.style.width = prefs.customSizeChat.width + 'px';
        chatBox.style.height = prefs.customSizeChat.height + 'px';
        updateFontSize(prefs.customSizeChat.width);
    }

    renderChatShortcuts();
    renderTabsAndContainers();
    
    if (typeof GetParentResourceName === 'function') {
        fetch(`https://${GetParentResourceName()}/requestSuggestions`, { method: 'POST' });
    }
});
