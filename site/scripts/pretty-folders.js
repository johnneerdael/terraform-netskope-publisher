// For each generated <name>.html (other than index.html) under source/,
// also emit <name>/index.html. Makes /foo/ URLs work alongside /foo.html.

const path = require('path');

hexo.extend.generator.register('pretty-folders', function (locals) {
  const out = [];
  locals.pages.forEach((page) => {
    const p = page.path;
    if (!p.endsWith('.html')) return;
    if (p.endsWith('/index.html')) return;
    const base = p.slice(0, -'.html'.length);
    out.push({
      path: base + '/index.html',
      data: page.content,
    });
  });
  return out;
});
