/**
 * Service worker — RitmoPatrimar, Estudo de Datas de Produção.
 *
 * POR QUE EXISTE: na fábrica a rede cai. O pdf.js sozinho tem 1,4 MB, e sem
 * ele o app não lê arquivo nenhum. Instalado, o app abre e funciona offline —
 * os PDFs já são lidos dentro do navegador, então não falta mais nada.
 *
 * A ESTRATÉGIA, e por que não é a mesma para tudo:
 *
 *   index.html  → REDE PRIMEIRO, cache como reserva.
 *     É onde mora o app inteiro (HTML, CSS, JS e as regras de conferência).
 *     Servir do cache primeiro faria a correção de uma regra de apontamento
 *     demorar dias para chegar ao usuário — e ele estaria conferindo lote com
 *     regra velha sem saber. Errar para o lado de buscar na rede é barato;
 *     errar para o lado do cache mostra número errado.
 *
 *   vendor/, ícones → CACHE PRIMEIRO.
 *     São grandes e imutáveis: o pdf.js 3.11.174 não muda de conteúdo. Se
 *     mudar de versão, muda o nome do cache abaixo e tudo é rebaixado junto.
 *
 * O cache é nomeado pela versão do app. Ao publicar uma versão nova, o
 * activate apaga todos os caches de nome diferente — não sobra resto de
 * versão antiga ocupando espaço nem sendo servido por engano.
 */
const VERSAO = '1.4.0';
const CACHE = 'ritmopatrimar-datas-v' + VERSAO;

const ESTATICOS = [
  './',
  './index.html',
  './vendor/pdf.min.js',
  './vendor/pdf.worker.min.js',
  './favicon.svg',
  './icone-192.png',
  './icone-512.png',
  './icone-maskable.png',
  './manifest.webmanifest',
];

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Um arquivo que falhe não pode abortar a instalação inteira: sem isto,
    // um 404 em qualquer item deixaria o app sem service worker nenhum.
    await Promise.all(ESTATICOS.map(u =>
      cache.add(new Request(u, { cache: 'reload' })).catch(() => {})));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    const nomes = await caches.keys();
    await Promise.all(nomes.filter(n => n !== CACHE).map(n => caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  // Só GET e só a própria origem. POST não se cacheia, e nada de outro
  // domínio passa por aqui — o app não fala com servidor nenhum.
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  const ehPagina = req.mode === 'navigate' ||
    (req.destination === 'document') ||
    url.pathname.endsWith('/index.html') ||
    url.pathname === '/' || url.pathname === '';

  if (ehPagina) {
    e.respondWith((async () => {
      try {
        const resp = await fetch(req);
        // Guarda a versão nova para a próxima vez que estiver sem rede.
        if (resp && resp.ok) (await caches.open(CACHE)).put('./index.html', resp.clone());
        return resp;
      } catch {
        return (await caches.match('./index.html')) ||
               (await caches.match('./')) ||
               new Response('Sem conexão e sem cópia local do aplicativo.',
                 { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
      }
    })());
    return;
  }

  e.respondWith((async () => {
    const cacheado = await caches.match(req);
    if (cacheado) return cacheado;
    try {
      const resp = await fetch(req);
      if (resp && resp.ok && resp.type === 'basic') {
        (await caches.open(CACHE)).put(req, resp.clone());
      }
      return resp;
    } catch (err) {
      return new Response('', { status: 504 });
    }
  })());
});
