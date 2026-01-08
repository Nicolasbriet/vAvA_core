/**
 * vAvA_keys - Interface JavaScript
 */

let keysVisible = false;

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'showKeys':
            showKeysUI(data.keys);
            break;
        case 'hideKeys':
            hideKeysUI();
            break;
    }
});

function showKeysUI(keys) {
    const ui = document.getElementById('keys-ui');
    const content = document.getElementById('keys-content');
    
    content.innerHTML = '';
    
    if (!keys || Object.keys(keys).length === 0) {
        content.innerHTML = '<div class="no-keys">Aucune clé de véhicule</div>';
    } else {
        for (const [plate, data] of Object.entries(keys)) {
            const item = document.createElement('div');
            item.className = 'key-item';
            item.innerHTML = `
                <div>
                    <div class="plate">${plate}</div>
                    <div class="type">${data.type || 'Propriétaire'}</div>
                </div>
                <div class="actions">
                    <button class="btn btn-lock" onclick="lockVehicle('${plate}')">🔒</button>
                    <button class="btn btn-share" onclick="shareKey('${plate}')">🤝</button>
                </div>
            `;
            content.appendChild(item);
        }
    }
    
    ui.style.display = 'block';
    keysVisible = true;
}

function hideKeysUI() {
    document.getElementById('keys-ui').style.display = 'none';
    keysVisible = false;
}

function lockVehicle(plate) {
    fetch(`https://${GetParentResourceName()}/lockVehicle`, {
        method: 'POST',
        body: JSON.stringify({ plate: plate })
    });
}

function shareKey(plate) {
    fetch(`https://${GetParentResourceName()}/shareKey`, {
        method: 'POST',
        body: JSON.stringify({ plate: plate })
    });
}

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && keysVisible) {
        hideKeysUI();
        fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
    }
});
