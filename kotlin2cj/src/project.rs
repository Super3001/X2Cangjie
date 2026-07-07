//! 项目级转换：将 Kotlin 项目目录转换为仓颉 cjpm 项目。
//!
//! 职责：
//! - 扫描目录中的 .kt 文件
//! - 提取 package/import 信息
//! - 合并翻译（利用完整类型上下文）
//! - 拆分输出到多文件（每个 .kt → 一个 .cj）
//! - 生成 cjpm.toml 和目录结构

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

/// 项目转换的结果。
pub struct ProjectResult {
    pub output_dir: PathBuf,
    pub files_translated: usize,
    pub files_failed: Vec<(PathBuf, String)>,
}

/// 将 Kotlin 包名转换为仓颉包名。
fn map_package_name(kotlin_pkg: &str) -> String {
    kotlin_pkg
        .rsplit('.')
        .next()
        .unwrap_or(kotlin_pkg)
        .to_string()
}

fn sanitize_cjpm_name(name: &str) -> String {
    let mut out = String::new();
    for ch in name.chars() {
        if ch.is_ascii_alphanumeric() || ch == '_' {
            out.push(ch);
        } else {
            out.push('_');
        }
    }
    if out.is_empty() || out.chars().next().is_some_and(|c| c.is_ascii_digit()) {
        out.insert(0, '_');
    }
    out
}

/// 生成 cjpm.toml 内容。
fn generate_cjpm_toml(project_name: &str, has_main: bool) -> String {
    let output_type = if has_main { "executable" } else { "static" };
    format!(
        r#"[package]
  cjc-version = "1.0.5"
  name = "{name}"
  version = "1.0.0"
  output-type = "{output_type}"
"#,
        name = project_name,
        output_type = output_type
    )
}

/// 判断文件是否包含 main 函数。
fn has_main_func(src: &str) -> bool {
    for line in src.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("fun main(")
            || trimmed == "fun main() {"
            || trimmed.starts_with("fun main()")
        {
            return true;
        }
    }
    false
}

/// 为一段仓颉代码检测需要的 import 并生成 import 块。
fn detect_and_gen_imports(cj_code: &str) -> Vec<String> {
    let mut imports: Vec<String> = Vec::new();
    if cj_code.contains("ArrayList")
        || cj_code.contains("HashMap")
        || cj_code.contains("HashSet")
        || cj_code.contains("MutableList")
    {
        imports.push("import std.collection.*".to_string());
    }
    if cj_code.contains("@Derive") {
        imports.push("import std.deriving.*".to_string());
    }
    if cj_code.contains("sort(") {
        imports.push("import std.sort.*".to_string());
    }
    // 注意：不要为 Iterator 注入 import——仓颉 1.0.5 没有 std.iterator 包，
    // Iterator/Iterable 在 core 中自动可用。
    if cj_code.contains("convert") || cj_code.contains("toString()") {
        imports.push("import std.convert.*".to_string());
    }
    imports.sort();
    // 去重
    let mut seen = HashSet::new();
    imports.retain(|i| seen.insert(i.clone()));
    imports
}

/// 源文件名 → 仓颉输出文件名（小写，.kt → .cj）。
fn kt_to_cj_filename(kt_path: &Path) -> String {
    let stem = kt_path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("unnamed");
    // 转为小写下划线风格
    let mut out = String::new();
    for (i, ch) in stem.chars().enumerate() {
        if ch.is_ascii_uppercase() {
            if i > 0 {
                out.push('_');
            }
            out.push(ch.to_ascii_lowercase());
        } else {
            out.push(ch);
        }
    }
    format!("{}.cj", out)
}

/// 执行项目级转换。
///
/// 策略：
/// 1. 合并所有 .kt 文件到一个翻译单元（保持完整类型上下文）
/// 2. 记录每个文件的字节范围
/// 3. 翻译后按源文件拆分输出为多个 .cj 文件
/// 4. 生成 cjpm.toml
pub fn convert_project(input_dir: &Path, output_dir: &Path) -> Result<ProjectResult, String> {
    // 1. 扫描 .kt 文件
    let kt_files = scan_kt_files(input_dir)?;
    if kt_files.is_empty() {
        return Err(format!("目录 {} 中没有找到 .kt 文件", input_dir.display()));
    }

    // 2. 确定项目名称
    let project_name = output_dir
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("project")
        .to_string();
    let cangjie_pkg = sanitize_cjpm_name(&map_package_name(&project_name));

    // 3. 创建输出目录结构
    let src_dir = output_dir.join("src");
    std::fs::create_dir_all(&src_dir).map_err(|e| format!("创建目录失败: {}", e))?;

    // 4. 读取所有文件，构建合并源码 + 字节范围映射
    let mut file_ranges: Vec<(PathBuf, usize, usize)> = Vec::new(); // (path, start, end)
    let mut file_has_main: Vec<bool> = Vec::new();
    let mut merged_source = String::new();

    // 收集非 main 文件先，main 文件后（确保 main 在正确位置）
    let mut non_main: Vec<(PathBuf, String)> = Vec::new();
    let mut main_files: Vec<(PathBuf, String)> = Vec::new();

    for kt in &kt_files {
        let src = std::fs::read_to_string(kt)
            .map_err(|e| format!("读取 {} 失败: {}", kt.display(), e))?;
        if has_main_func(&src) {
            main_files.push((kt.clone(), src));
        } else {
            non_main.push((kt.clone(), src));
        }
    }

    // 按序合并，记录字节范围
    for (path, src) in non_main.iter().chain(main_files.iter()) {
        let start = merged_source.len();
        merged_source.push_str(src);
        merged_source.push('\n');
        let end = merged_source.len();
        file_ranges.push((path.clone(), start, end));
        file_has_main.push(has_main_func(src));
    }

    // 5. 合并翻译
    let toks = crate::lexer::Lexer::new(&merged_source)
        .tokenize()
        .map_err(|e| format!("词法分析失败: {}", e))?;

    let mut p = crate::parser::Parser::new(toks);
    // 传入文件字节范围（仅 start/end，Parser 不需要路径）
    let byte_ranges: Vec<(usize, usize)> = file_ranges.iter().map(|(_, s, e)| (*s, *e)).collect();
    p.set_file_ranges(byte_ranges);
    p.parse_program()
        .map_err(|e| format!("语法分析失败: {}", e))?;

    let mut eng = crate::engine::Engine::new(p.g);
    eng.relax();

    // 6. 收集 Program items 并按源文件分组
    let root = eng.g.root;
    let items: Vec<crate::node::NodeId> = match &eng.g.nodes[root].kind {
        crate::node::Kind::Program { items } => items.clone(),
        _ => return Err("内部错误: 根节点不是 Program".to_string()),
    };

    // 按 source_file 分组
    let mut file_items: Vec<Vec<crate::node::NodeId>> = vec![Vec::new(); file_ranges.len()];
    let mut any_has_main = false;
    for &item_id in &items {
        let sf = eng.g.nodes[item_id].source_file.unwrap_or(0);
        if sf < file_items.len() {
            file_items[sf].push(item_id);
            if file_has_main[sf] {
                any_has_main = true;
            }
        }
    }

    // 7. 为每个源文件生成 .cj 输出
    let mut files_written = 0usize;
    let mut all_bodies = String::new(); // 汇总代码体，用于 stub 注入检测
    // 检测 basename 撞名,对撞名的加父目录前缀消歧
    // (1f 实例: dsl/KoinApplication.kt + core/KoinApplication.kt 都输出 koin_application.cj)
    let mut basename_count: HashMap<String, usize> = HashMap::new();
    for (path, _, _) in &file_ranges {
        let bn = kt_to_cj_filename(path);
        *basename_count.entry(bn).or_insert(0) += 1;
    }
    for (fi, item_ids) in file_items.iter().enumerate() {
        let kt_path = &file_ranges[fi].0;
        let cj_name = {
            let bn = kt_to_cj_filename(kt_path);
            if basename_count.get(&bn).copied().unwrap_or(0) > 1 {
                // 撞名,加父目录前缀消歧 (父目录名转 snake_case)
                let parent = kt_path
                    .parent()
                    .and_then(|p| p.file_name())
                    .and_then(|n| n.to_str())
                    .unwrap_or("");
                if !parent.is_empty() {
                    let mut parent_snake = String::new();
                    for (i, ch) in parent.chars().enumerate() {
                        if ch.is_ascii_uppercase() {
                            if i > 0 {
                                parent_snake.push('_');
                            }
                            parent_snake.push(ch.to_ascii_lowercase());
                        } else {
                            parent_snake.push(ch);
                        }
                    }
                    format!("{}_{}", parent_snake, bn)
                } else {
                    bn
                }
            } else {
                bn
            }
        };

        // 渲染该文件的所有声明
        let mut body = String::new();
        for &item_id in item_ids {
            if let Some(rendered) = eng.g.nodes[item_id].state.target.as_deref() {
                if !body.is_empty() {
                    body.push('\n');
                }
                body.push_str(rendered);
            }
        }
        if body.trim().is_empty() {
            continue; // 跳过空文件
        }

        // 注入运行时辅助函数（与 render_program 对齐）
        let body = if body.contains("__k2cjRuneSlice(") {
            let helper = r#"func __k2cjRuneSlice(input: String, start: Int64, end: Int64): String {
    let _r = input.toRuneArray()
    let _out = Array<Rune>(end - start, { _ => r'\u{0000}' })
    var _i = 0
    while (_i < end - start) {
        _out[_i] = _r[start + _i]
        _i++
    }
    String(_out)
}
"#;
            format!("{}\n{}", helper, body)
        } else {
            body
        };

        // 汇总代码体（stub 注入检测用）
        all_bodies.push_str(&body);
        all_bodies.push('\n');

        // 检测需要的 import
        let imports = detect_and_gen_imports(&body);

        // 组装输出
        let mut output = String::new();
        output.push_str(&format!("package {}\n\n", cangjie_pkg));
        for imp in &imports {
            output.push_str(imp);
            output.push('\n');
        }
        if !imports.is_empty() {
            output.push('\n');
        }
        output.push_str(&body);
        if !output.ends_with('\n') {
            output.push('\n');
        }

        let out_path = src_dir.join(&cj_name);
        std::fs::write(&out_path, &output)
            .map_err(|e| format!("写入 {} 失败: {}", out_path.display(), e))?;
        files_written += 1;
    }

    if files_written == 0 {
        return Err("翻译后没有生成任何有效文件".to_string());
    }

    // 7.5 注入 Kotlin stdlib 类型面 stub（同包共享，写入独立文件避免重复定义）
    if let Some((stub_imports, stub_code)) = crate::stubs::collect_stubs(&all_bodies) {
        let mut stub_file = String::new();
        stub_file.push_str(&format!("package {}\n\n", cangjie_pkg));
        for imp in &stub_imports {
            stub_file.push_str(imp);
            stub_file.push('\n');
        }
        if !stub_imports.is_empty() {
            stub_file.push('\n');
        }
        stub_file.push_str(&stub_code);
        if !stub_file.ends_with('\n') {
            stub_file.push('\n');
        }
        let stub_path = src_dir.join("k2cj_stubs.cj");
        std::fs::write(&stub_path, &stub_file)
            .map_err(|e| format!("写入 {} 失败: {}", stub_path.display(), e))?;
        files_written += 1;
    }

    // 8. 生成 cjpm.toml
    let toml_content = generate_cjpm_toml(&cangjie_pkg, any_has_main);
    std::fs::write(output_dir.join("cjpm.toml"), &toml_content)
        .map_err(|e| format!("写入 cjpm.toml 失败: {}", e))?;

    Ok(ProjectResult {
        output_dir: output_dir.to_path_buf(),
        files_translated: files_written,
        files_failed: Vec::new(),
    })
}

/// 递归扫描目录中的 .kt 文件。
fn scan_kt_files(dir: &Path) -> Result<Vec<PathBuf>, String> {
    let mut files = Vec::new();
    scan_kt_recursive(dir, &mut files)?;
    files.sort();
    Ok(files)
}

fn scan_kt_recursive(dir: &Path, files: &mut Vec<PathBuf>) -> Result<(), String> {
    let entries =
        std::fs::read_dir(dir).map_err(|e| format!("无法读取目录 {}: {}", dir.display(), e))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("读取目录项失败: {}", e))?;
        let path = entry.path();
        if path.is_dir() {
            // 跳过常见非源码目录
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if name.starts_with('.')
                || name == "build"
                || name == "target"
                || name == "node_modules"
                || name == ".gradle"
            {
                continue;
            }
            scan_kt_recursive(&path, files)?;
        } else if path.extension().and_then(|e| e.to_str()) == Some("kt") {
            files.push(path);
        }
    }
    Ok(())
}
