// Identity, Licenses, Stats, History JavaScript
const Identity = {
    show: function(data) {
        document.getElementById('idcard').classList.remove('hidden');
        document.getElementById('idName').textContent = data.lastname;
        document.getElementById('idFirstname').textContent = data.firstname;
        document.getElementById('idDOB').textContent = data.dateofbirth;
        document.getElementById('idSex').textContent = data.sex === 'm' ? 'Homme' : 'Femme';
        document.getElementById('idPhone').textContent = data.phone || 'N/A';
        document.getElementById('idCitizen').textContent = data.citizenid;
        document.getElementById('idJob').textContent = data.job || 'Sans emploi';
    },
    close: function() {
        document.getElementById('idcard').classList.add('hidden');
        fetch(`https://${GetParentResourceName()}/closeIDCard`, {method: 'POST', body: JSON.stringify({})});
    }
};

const Licenses = {
    show: function(licenses, available) {
        document.getElementById('licenses').classList.remove('hidden');
        const grid = document.getElementById('licensesGrid');
        grid.innerHTML = '';
        available.forEach(lic => {
            const owned = licenses.find(l => l.license_type === lic.name);
            const card = document.createElement('div');
            card.className = 'license-card';
            card.innerHTML = `
                <h3>${lic.label}</h3>
                <p>${lic.description}</p>
                <p><strong>Coût:</strong> $${lic.cost}</p>
                <p><strong>Validité:</strong> ${lic.validityDays > 0 ? lic.validityDays + ' jours' : 'Illimité'}</p>
                ${owned ? `<span class="license-status valid">✓ Possédée</span>` : `<button class="btn-obtain" data-type="${lic.name}">Obtenir - $${lic.cost}</button>`}
            `;
            grid.appendChild(card);
        });
        document.querySelectorAll('.btn-obtain').forEach(btn => {
            btn.addEventListener('click', () => {
                fetch(`https://${GetParentResourceName()}/buyLicense`, {method: 'POST', body: JSON.stringify({licenseType: btn.dataset.type})});
            });
        });
    },
    close: function() {
        document.getElementById('licenses').classList.add('hidden');
        fetch(`https://${GetParentResourceName()}/closeLicenses`, {method: 'POST', body: JSON.stringify({})});
    }
};

const Stats = {
    show: function(stats) {
        document.getElementById('stats').classList.remove('hidden');
        const grid = document.getElementById('statsGrid');
        grid.innerHTML = '';
        stats.forEach(stat => {
            const card = document.createElement('div');
            card.className = 'stat-card';
            card.innerHTML = `
                <div class="icon">${stat.icon}</div>
                <div class="value">${stat.value}</div>
                <div class="label">${stat.label}</div>
            `;
            grid.appendChild(card);
        });
    },
    close: function() {
        document.getElementById('stats').classList.add('hidden');
        fetch(`https://${GetParentResourceName()}/closeStats`, {method: 'POST', body: JSON.stringify({})});
    }
};

const History = {
    show: function(history) {
        document.getElementById('history').classList.remove('hidden');
        this.renderHistory(history);
    },
    renderHistory: function(history) {
        const list = document.getElementById('historyList');
        list.innerHTML = '';
        history.forEach(event => {
            const item = document.createElement('div');
            item.className = 'history-item';
            item.innerHTML = `
                <div class="icon">${event.icon}</div>
                <div class="details">
                    <div class="type">${event.typeLabel}</div>
                    <div class="description">${event.description}</div>
                    <div class="date">${event.date}</div>
                </div>
                ${event.amount ? `<div class="amount">${event.amount}</div>` : ''}
            `;
            list.appendChild(item);
        });
    },
    close: function() {
        document.getElementById('history').classList.add('hidden');
        fetch(`https://${GetParentResourceName()}/closeHistory`, {method: 'POST', body: JSON.stringify({})});
    }
};

document.getElementById('btnCloseID').addEventListener('click', () => Identity.close());
document.getElementById('btnCloseLicenses').addEventListener('click', () => Licenses.close());
document.getElementById('btnCloseStats').addEventListener('click', () => Stats.close());
document.getElementById('btnCloseHistory').addEventListener('click', () => History.close());
document.getElementById('btnLoadMore').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/loadMoreHistory`, {method: 'POST', body: JSON.stringify({limit: 50})})
        .then(res => res.json()).then(data => History.renderHistory(data));
});
