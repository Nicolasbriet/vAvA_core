// vAvA Player Manager - Créateur JavaScript
const Creator = {
    config: null,
    
    open: function(config) {
        this.config = config;
        document.getElementById('creator').classList.remove('hidden');
        this.setupForm();
    },
    
    close: function() {
        document.getElementById('creator').classList.add('hidden');
        this.clearForm();
    },
    
    setupForm: function() {
        const nationalitySelect = document.getElementById('nationality');
        nationalitySelect.innerHTML = '';
        this.config.nationalities.forEach(nat => {
            const option = document.createElement('option');
            option.value = nat;
            option.textContent = nat;
            if (nat === this.config.defaultNationality) option.selected = true;
            nationalitySelect.appendChild(option);
        });
        
        if (!this.config.storyMode) {
            document.getElementById('storySection').style.display = 'none';
        }
    },
    
    clearForm: function() {
        document.getElementById('firstname').value = '';
        document.getElementById('lastname').value = '';
        document.getElementById('dateofbirth').value = '';
        document.getElementById('background').value = '';
        document.getElementById('reason').value = '';
        document.getElementById('goal').value = '';
    },
    
    create: function() {
        const data = {
            firstname: document.getElementById('firstname').value.trim(),
            lastname: document.getElementById('lastname').value.trim(),
            dateofbirth: document.getElementById('dateofbirth').value.trim(),
            sex: document.getElementById('sex').value,
            nationality: document.getElementById('nationality').value,
            background: document.getElementById('background').value.trim(),
            reason: document.getElementById('reason').value.trim(),
            goal: document.getElementById('goal').value.trim()
        };
        
        if (!data.firstname || !data.lastname || !data.dateofbirth) {
            alert('Veuillez remplir tous les champs obligatoires');
            return;
        }
        
        fetch(`https://${GetParentResourceName()}/createCharacter`, {
            method: 'POST',
            body: JSON.stringify(data)
        }).then(res => res.json()).then(result => {
            if (result.error) {
                alert(result.error);
            } else {
                this.close();
            }
        });
    }
};

document.getElementById('btnConfirmCreate').addEventListener('click', () => Creator.create());
document.getElementById('btnCancelCreator').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/cancelCreator`, {method: 'POST', body: JSON.stringify({})});
});
document.getElementById('sex').addEventListener('change', (e) => {
    fetch(`https://${GetParentResourceName()}/updateCharacterPreview`, {method: 'POST', body: JSON.stringify({sex: e.target.value})});
});
