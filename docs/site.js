const repo = 'flamses/Roblox-Mac-Account-Manager';
document.querySelectorAll('[data-mode]').forEach(button => {
  button.addEventListener('click', () => {
    const together = button.dataset.mode === 'together';
    document.querySelectorAll('[data-mode]').forEach(item => {
      const selected = item === button;
      item.classList.toggle('selected', selected);
      item.setAttribute('aria-pressed', String(selected));
    });
    document.querySelector('.mock-main h2').textContent = together ? 'Better together.' : 'Do your own thing.';
    document.querySelectorAll('[data-game]').forEach((item, index) => {
      item.textContent = together ? 'Same server' : `Game ${String.fromCharCode(65 + index)}`;
    });
  });
});
// Keep the download current; the hardcoded release remains usable if GitHub's API is unavailable.
fetch(`https://api.github.com/repos/${repo}/releases/latest`, { headers: { Accept: 'application/vnd.github+json' } })
  .then(response => { if (!response.ok) throw new Error('Release unavailable'); return response.json(); })
  .then(release => {
    const asset = release.assets?.find(item => /^MacBlox-v[\d.]+-macOS-AppleSilicon\.zip$/.test(item.name));
    if (!asset) return;
    const url = new URL(asset.browser_download_url);
    if (url.protocol !== 'https:' || url.hostname !== 'github.com' || !url.pathname.startsWith(`/${repo}/releases/download/`)) return;
    document.querySelectorAll('.download-link').forEach(link => { link.href = url.href; });
  })
  .catch(() => {});
