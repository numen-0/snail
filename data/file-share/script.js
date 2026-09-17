const uploadForm = document.getElementById('upload-form');
const mkdirForm = document.getElementById('mkdir-form');
const deleteButtons = document.querySelectorAll('.delete')

printable_ascii_re = /^[\x20-\x7e]+$/

function swapToApi(path) {
    return path.replace(/^\/web/, '/api');
}

function isValidName(name) {
    return name
        && name !== '.'
        && name !== '..'
        && !name.includes('/')
        && printable_ascii_re.test(name)
        ;;
}

uploadForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    const name = document.getElementById('upload-name').value;
    const file = document.getElementById('upload-file').files[0];

    if ( !file || !name ) { return; }

    if ( !isValidName(name) ) {
        alert('Invalid filename');
        return;
    }

    const path = swapToApi(window.location.pathname)
        + encodeURIComponent(name);

    let response = await fetch(path, {
        method: 'POST',
        body: file
    });

    if ( response.status === 409 ) {
        response = await fetch(path, {
            method: 'PUT',
            body: file
        });
    }

    if ( !response.ok ) {
        alert(await response.text());
        return;
    }

    location.reload();
});

mkdirForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    const name = document.getElementById('mkdir-name').value;

    if ( !name ) { return; }

    if ( !isValidName(name) ) {
        alert('Invalid directory name');
        return;
    }

    const path = swapToApi(window.location.pathname)
        + encodeURIComponent(name)
        + '/';

    const response = await fetch(path, {
        method: 'POST'
    });

    if ( !response.ok ) {
        alert(await response.text());
        return;
    }

    location.reload();
});

deleteButtons.forEach((button) => {
    button.addEventListener('click', async () => {
        if ( !confirm('Delete this file?') ) { return; }

        const path = swapToApi(button.dataset.path)

        const response = await fetch(path, {
            method: 'DELETE'
        });

        if ( !response.ok ) {
            alert(await response.text());
            return;
        }

        location.reload();
    });
});

