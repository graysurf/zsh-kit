#!/bin/bash

random_emoji() {
  local emojis=(
    ✨ 🌟 🚀 🧠 🐋 🎯 🔥 🍀 📚 💡 💬 🛠️ 🧩 🧘 🥷 🐾 🍎 🌈 🐱 🐳
    🍺 🌍 🎵 🌅 🌌 🧃 🎉 🧊 🪄 🪐 ⚡ 🧪 🧬 🧱 ⚙️ 🛸 🔮 🧲 🧨 🧵 🧶
    🪢 📦 🗃️ 📂 📈 📉 🧾 🪪 🧰 🗜️ 🪛 🪚 🔧 🔩 🪤 🎓 🧑‍💻 👨‍🔬 👩‍🚀
    🧙‍♂️ 🧙‍♀️ 👁️ 🧿 🪬 🪞 🐧 🐼 🐦 🦊 🐢 🐌 🐝 🐞 🦂 🕸️ 🕷️ 🦜 🦉 🦖
    🦕 🪴 🌵 🌿 🍂 🍁 🌻 🌼 🌷 🪻 🌺 🌸 🪷 🌞 🌝 🌚 🌜 🌊 🌬️ 🌪️
  )
  local total=${#emojis[@]}
  local idx=$(( (RANDOM + $(date +%N)) % total + 1 ))
  echo "${emojis[$idx]}"
}