random_emoji() {
  typeset emojis=(
    ✨ 🌟 🚀 🧠 🐋 🎯 🔥 🍀 📚 💡 💬 🛠️ 🧩 🧘 🥷 🐾 🍎 🌈 🐱 🐳
    🍺 🌍 🎵 🌅 🌌 🧃 🎉 🧊 🪄 🪐 ⚡ 🧪 🧬 🧱 ⚙️ 🛸 🔮 🧲 🧨 🧵 🧶
    🪢 📦 🗃️ 📂 📈 📉 🧾 🪪 🧰 🗜️ 🪛 🪚 🔧 🔩 🪤 🎓 🧑‍💻 👨‍🔬 👩‍🚀
    🧙‍♂️ 🧙‍♀️ 👁️ 🧿 🪬 🪞 🐧 🐼 🐦 🦊 🐢 🐌 🐝 🐞 🦂 🕸️ 🕷️ 🦜 🦉 🦖
    🦕 🪴 🌵 🌿 🍂 🍁 🌻 🌼 🌷 🪻 🌺 🌸 🪷 🌞 🌝 🌚 🌜 🌊 🌬️ 🌪️
  )
  typeset total=${#emojis[@]}
  typeset idx=$(( (RANDOM + $(date +%N)) % total + 1 ))
  printf "%s\n" "${emojis[$idx]}"
}
