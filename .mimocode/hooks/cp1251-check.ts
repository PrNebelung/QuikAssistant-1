export default {
  "tool.execute.after": async (input, output) => {
    // After any bash command that might modify .lua files, check encoding
    if (input.tool === "bash" && output.result) {
      const command = input.args?.command || "";
      // Check if command modifies lua files
      if (
        command.includes(".lua") &&
        (command.includes("Remove-Item") ||
          command.includes("Rename-Item") ||
          command.includes("git checkout") ||
          command.includes("git add") ||
          command.includes("python"))
      ) {
        // Add encoding check reminder to output
        output.result += "\n\n[CP1251 GUARD] Remember to run: python cp1251_wrapper.py check_all";
      }
    }

    // After write tool, warn if writing to .lua file
    if (input.tool === "write" && input.args?.file_path?.endsWith(".lua")) {
      output.result =
        "[CP1251 GUARD] WARNING: You just wrote a .lua file. If it contains Russian text, " +
        "you MUST convert it to cp1251 encoding. Use: python -c \"open('file.lua','wb').write(open('file.lua','r',encoding='utf-8').read().encode('cp1251'))\"\n\n" +
        output.result;
    }

    // After edit tool, warn if editing .lua file
    if (input.tool === "edit" && input.args?.file_path?.endsWith(".lua")) {
      output.result =
        "[CP1251 GUARD] WARNING: You just edited a .lua file with the Edit tool. " +
        "If the file contains Russian text, the encoding may be corrupted. " +
        "Run: python cp1251_wrapper.py check_all\n\n" +
        output.result;
    }
  },
};
