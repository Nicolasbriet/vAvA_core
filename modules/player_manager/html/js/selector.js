// vAvA Player Manager - Sélecteur JavaScript
const Selector = {
    characters: [],
    selectedIndex: null,
    
    open: function(characters, config) {
        this.characters = characters;
        document.getElementById('selector').classList.remove('hidden');
        document.getElementById('charCount').textContent = `${characters.length}/${config.maxCharacters}`;
        this.renderCharacters();
    },
    
    close: function() {
        document.getElementById('selector').classList.add('hidden');
        fetch(`https://${GetParentResourceName()}/closeSelector`, {method: 'POST', body: JSON.stringify({})});
    },
    
    renderCharacters: function() {
        const grid = document.getElementById('charactersGrid');
        grid.innerHTML = '';
        
        this.characters.forEach((char, index) => {
            const card = document.createElement('div');
            card.className = 'character-card';
            card.innerHTML = `
                <h3>${char.firstname} ${char.lastname}</h3>
                <p><strong>Date de naissance:</strong> ${char.dateofbirth}</p>
                <p class="job"><strong>Emploi:</strong> ${char.job || 'Sans emploi'}</p>
                <p><strong>Dernière connexion:</strong> ${this.formatDate(char.last_played)}</p>
                <p><strong>Temps de jeu:</strong> ${Math.floor(char.playtime / 3600)}h</p>
                <div class="character-actions">
                    <button class="btn-play" data-index="${index}">JOUER</button>
                    <button class="btn-delete" data-index="${index}">SUPPRIMER</button>
                </div>
            `;
            
            card.addEventListener('click', (e) => {
                if (!e.target.closest('button')) {
                    this.selectCharacter(index);
                }
            });
            
            grid.appendChild(card);
        });
        
        document.querySelectorAll('.btn-play').forEach(btn => {
            btn.addEventListener('click', () => this.playCharacter(parseInt(btn.dataset.index)));
        });
        
        document.querySelectorAll('.btn-delete').forEach(btn => {
            btn.addEventListener('click', () => this.deleteCharacter(parseInt(btn.dataset.index)));
        });
    },
    
    selectCharacter: function(index) {
        this.selectedIndex = index;
        document.querySelectorAll('.character-card').forEach((card, i) => {
            card.classList.toggle('selected', i === index);
        });
        fetch(`https://${GetParentResourceName()}/selectCharacter`, {method: 'POST', body: JSON.stringify({index: index + 1})});
    },
    
    playCharacter: function(index) {
        this.selectedIndex = index;
        fetch(`https://${GetParentResourceName()}/playCharacter`, {method: 'POST', body: JSON.stringify({})});
    },
    
    deleteCharacter: function(index) {
        if (confirm('Êtes-vous sûr de vouloir supprimer ce personnage?')) {
            this.selectedIndex = index;
            fetch(`https://${GetParentResourceName()}/deleteCharacter`, {method: 'POST', body: JSON.stringify({})});
        }
    },
    
    formatDate: function(dateStr) {
        const date = new Date(dateStr);
        return date.toLocaleDateString('fr-FR') + ' ' + date.toLocaleTimeString('fr-FR');
    }
};

document.getElementById('btnCreate').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/createCharacter`, {method: 'POST', body: JSON.stringify({})});
});
