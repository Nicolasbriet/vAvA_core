// vAvA Player Manager - Main JavaScript
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'openSelector':
            Selector.open(data.characters, data.config);
            break;
        case 'closeSelector':
            Selector.close();
            break;
        case 'openCreator':
            Creator.open(data.config);
            break;
        case 'showIDCard':
            Identity.show(data.data);
            break;
        case 'closeIDCard':
            Identity.close();
            break;
        case 'showLicenses':
            Licenses.show(data.licenses, data.availableLicenses);
            break;
        case 'showStats':
            Stats.show(data.stats);
            break;
        case 'showHistory':
            History.show(data.history);
            break;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!document.getElementById('selector').classList.contains('hidden')) Selector.close();
        if (!document.getElementById('creator').classList.contains('hidden')) Creator.close();
        if (!document.getElementById('idcard').classList.contains('hidden')) Identity.close();
        if (!document.getElementById('licenses').classList.contains('hidden')) Licenses.close();
        if (!document.getElementById('stats').classList.contains('hidden')) Stats.close();
        if (!document.getElementById('history').classList.contains('hidden')) History.close();
    }
});

function GetParentResourceName() {
    return 'vAvA_core';
}
