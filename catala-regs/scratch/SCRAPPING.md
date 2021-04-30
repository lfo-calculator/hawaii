On https://sammade.github.io/aloha-io/title-17/chapter-286/section-286-136/:

Open up the JavaScript console, then:

```
objs = [];
for (let i = 7230; i < 7283; ++i) {
  let l = document.querySelectorAll(".sidebar-item")[i];
  if (l.textContent.indexOf("Repealed") >= 0)
    continue;
  let s = l.textContent.indexOf(" ");
  let section = l.textContent.substring(0, s);
  let title = l.textContent.substring(s+1);
  objs.push({ regulation: title, reg_url: l.querySelector("a").href, catala_url: section + ".catala_en" })
}
console.log(JSON.stringify(objs))
```

This dumps the JSON data for the section we care about! Then, possibly, use any
JSON formatter/beautifier out there.

TODO: use this to fill out and auto-generate the JSON entirely
