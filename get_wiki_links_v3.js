const crypto = require('crypto');
const fs = require('fs');

const files = [
    'Hà_Nội.ogg',
    'Saigon.ogg',
    'Vi-hanoi-m-ba.ogg',
    'Vi-hanoi-m-mười.ogg',
    'Vietnam.ogg',
    'Bien_Hoa_Southern.ogg',
    'Vi-hanoi-m-nói.ogg',
    'Vi-hanoi-m-nay.ogg',
    'Vi-hanoi-m-rất.ogg'
];

let output = '';
files.forEach(f => {
    const hash = crypto.createHash('md5').update(f).digest('hex');
    const h1 = hash[0];
    const h2 = hash.substring(0, 2);
    output += `${f} -> https://upload.wikimedia.org/wikipedia/commons/${h1}/${h2}/${f}\n`;
});

fs.writeFileSync('d:/FPT/SWD305_Godot/wiki_urls_final.txt', output, 'utf8');
console.log('Done');
