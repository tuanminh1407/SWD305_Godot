const crypto = require('crypto');
const fs = require('fs');

const files = [
    'Hà_Nội.ogg',
    'Saigon.ogg',
    'Huế.ogg',
    'Vi-hanoi-m-ba.ogg',
    'Vi-hanoi-m-nói.ogg',
    'Vi-hanoi-m-mười.ogg',
    'Vi-hanoi-m-rất.ogg',
    'Vi-hanoi-m-nay.ogg',
    'Vi-hanoi-m-kiến.ogg',
    'Vietnam.ogg',
    'Vi-hanoi-m-em.ogg',
    'Vi-hanoi-m-chào.ogg',
    'Vi-hanoi-m-một.ogg',
    'Vi-hanoi-m-ông.ogg',
    'Vi-hanoi-m-bà.ogg',
    'Vi-hanoi-m-mẹ.ogg',
    'Vi-hanoi-m-bố.ogg',
    'Vi-hanoi-m-anh.ogg',
    'Vi-hanoi-m-chị.ogg'
];

let output = '';
files.forEach(f => {
    const hash = crypto.createHash('md5').update(f).digest('hex');
    const h1 = hash[0];
    const h2 = hash.substring(0, 2);
    output += `${f} -> https://upload.wikimedia.org/wikipedia/commons/${h1}/${h2}/${f}\n`;
});

fs.writeFileSync('d:/FPT/SWD305_Godot/wiki_urls_final.txt', output, 'utf8');
console.log('URLs written to wiki_urls_final.txt');
