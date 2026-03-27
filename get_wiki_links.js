const crypto = require('crypto');

const files = [
    'Vi-Hà Nội-bắc.ogg',
    'Vi-saigon-Sài Gòn.ogg',
    'Vi-saigon-mẹ.ogg',
    'Vi-hanoi-mẹ.ogg',
    'Vi-Hà_Nội-bắc.ogg',
    'Vi-saigon-Sài_Gòn.ogg',
    'Vi-saigon-mẹ.ogg',
    'Vi-hanoi-mẹ.ogg'
];

files.forEach(f => {
    const filename = f.replace(/ /g, '_');
    const hash = crypto.createHash('md5').update(filename).digest('hex');
    const h1 = hash[0];
    const h2 = hash.substring(0, 2);
    console.log(`${f} -> https://upload.wikimedia.org/wikipedia/commons/${h1}/${h2}/${filename}`);
});
