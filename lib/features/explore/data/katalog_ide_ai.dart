import '../domain/template_ai.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Katalog curated dari awesome-llm-apps (Shubham Saboo, Apache-2.0).
/// Hanya judul + deskripsi singkat; kode asli tetap tinggal di GitHub.
const List<IdeTemplate> katalogIdeAi = <IdeTemplate>[
  // ------------------------------------------------------------- Agent Skills
  IdeTemplate(
    id: 'project-graveyard',
    judul: 'Project Graveyard',
    deskripsi:
        'Mencari setiap proyek sampingan yang tertinggal dan membantu menyelesaikan yang layak diselesaikan.',
    kategori: 'Agent Skills',
    ikon: LucideIcons.brain,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/agent_skills/project-graveyard/',
    promptStarter:
        'Tolong saya mengurai daftar proyek sampingan yang belum selesai, sebutkan alasan masing-masing gagal, dan rekomendasikan satu yang layak diselesaikan dengan rencana 3 langkah pertama.',
  ),
  IdeTemplate(
    id: 'first-reader',
    judul: 'First Reader',
    deskripsi:
        'Menyimulasikan pembaca nyata menelusuri draft dan melaporkan di mana mereka kehilangan minat.',
    kategori: 'Agent Skills',
    ikon: LucideIcons.messageSquareText,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/agent_skills/first-reader/',
    promptStarter:
        'Saya akan menyalin draft tulisan saya. Tolong bacalah seperti pembaca baru dan katakan di mana saya kehilangan minat atau malas membaca, tanpa menulis ulang.',
  ),
  IdeTemplate(
    id: 'scope-creep',
    judul: 'Scope Creep Detector',
    deskripsi:
        'Memeriksa apakah perubahan tumbuh di luar niat awal dan merekomendasikan apa yang harus dijaga, dipisah, atau diabaikan.',
    kategori: 'Agent Skills',
    ikon: LucideIcons.code,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/agent_skills/scope-creep-detector/',
    promptStarter:
        'Saya akan melampirkan diff perubahan. Periksa apakah cakupan sudah melampaui niat awal dan saran apa yang harus dipertahankan, dipisah menjadi tugas terpisah, atau diabaikan.',
  ),
  IdeTemplate(
    id: 'dependency-doctor',
    judul: 'Dependency Doctor',
    deskripsi:
        'Memeriksa manifest dependensi untuk pin standar, backlapus usang, entri tidak terpandu, dan rilis yang dicabut.',
    kategori: 'Agent Skills',
    ikon: LucideIcons.code,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/agent_skills/dependency-doctor/',
    promptStarter:
        'Periksa file dependensi proyek saya (package.json / pubspec.yaml / requirements.txt) untuk pin versi yang tidak tepat, backlapus usang, dan duplikasi, lalu berikan saran perbaikan.',
  ),

  // ------------------------------------------------------------ Starter Agen
  IdeTemplate(
    id: 'data-analysis',
    judul: 'AI Data Analysis Agent',
    deskripsi: 'Tanyakan apa saja tentang file CSV atau Excel dalam bahasa Inggris.',
    kategori: 'Starter Agen',
    ikon: LucideIcons.database,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/starter_ai_agents/ai_data_analysis_agent/',
    promptStarter:
        'Saya akan mengunggah file data. Tolong analisiskan dan jawab pertanyaan saya tentang pola serta tren dalam data.',
  ),
  IdeTemplate(
    id: 'travel-agent',
    judul: 'AI Travel Agent',
    deskripsi: 'Itinerari perjalanan harian yang dipersonalisasi.',
    kategori: 'Starter Agen',
    ikon: LucideIcons.smartphone,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/starter_ai_agents/ai_travel_agent/',
    promptStarter:
        'Buatkan rencana perjalanan 5 hari ke [kota] untuk [berapa orang], dengan rekomendasi tempat makan dan aktivitas setiap hari.',
  ),
  IdeTemplate(
    id: 'meme-generator',
    judul: 'AI Meme Generator Agent',
    deskripsi:
        'Membuat memes dengan mengemudikan browser nyata, bukan API gambar.',
    kategori: 'Starter Agen',
    ikon: LucideIcons.smartphone,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/starter_ai_agents/ai_meme_generator_agent_browseruse/',
    promptStarter:
        'Buatkan ide meme tentang [topik] dengan caption yang lucu dan saran format gambar yang cocok.',
  ),
  IdeTemplate(
    id: 'web-scraping',
    judul: 'Web Scraping AI Agent',
    deskripsi: 'Jelaskan apa yang ingin diekstrak dan agen akan mencabutnya dari web.',
    kategori: 'Starter Agen',
    ikon: LucideIcons.code,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/starter_ai_agents/web_scraping_ai_agent/',
    promptStarter:
        'Saya ingin mengekstrak [informasi] dari [situs web]. Tolong tuliskan cara scraping-nya dan contoh hasilnya.',
  ),
  IdeTemplate(
    id: 'mixture-of-agents',
    judul: 'Mixture of Agents',
    deskripsi: 'Banyak LLM menjawab, satu yang mengagregasi jawaban terbaik.',
    kategori: 'Starter Agen',
    ikon: LucideIcons.users,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/starter_ai_agents/mixture_of_agents/',
    promptStarter:
        'Kirimkan pertanyaan saya ke beberapa model AI sekaligus, lalu gabungkan jawaban terbaik dari masing-masing menjadi satu jawaban akhir.',
  ),

  // ------------------------------------------------------------- Advanced
  IdeTemplate(
    id: 'deep-research',
    judul: 'AI Deep Research Agent',
    deskripsi:
        'Riset web komprehensif dengan OpenAI Agents SDK dan Firecrawl.',
    kategori: 'Advanced',
    ikon: LucideIcons.brain,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/single_agent_apps/ai_deep_research_agent/',
    promptStarter:
        'Lakukan riset mendalam tentang [topik] dari banyak sumber web dan buatkan ringkasan lengkap dengan kutipan sumber.',
  ),
  IdeTemplate(
    id: 'financial-coach',
    judul: 'AI Financial Coach Agent',
    deskripsi: 'Analisis anggaran, utang, dan taburan yang dipersonalisasi.',
    kategori: 'Advanced',
    ikon: LucideIcons.palette,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/multi_agent_apps/ai_financial_coach_agent/',
    promptStarter:
        'Analisis keuangan saya: pendapatan [X], pengeluaran [Y], utang [Z]. Buatkan rencana anggaran dan strategi pelunasan utang.',
  ),
  IdeTemplate(
    id: 'health-fitness',
    judul: 'AI Health & Fitness Agent',
    deskripsi: 'Rencana diet dan latihan dari tujuan Anda.',
    kategori: 'Advanced',
    ikon: LucideIcons.smartphone,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/single_agent_apps/ai_health_fitness_agent/',
    promptStarter:
        'Buatkan rencana diet dan latihan 4 minggu untuk tujuan [turunkan berat badan / otot] dengan ketersediaan waktu [X jam/minggu].',
  ),
  IdeTemplate(
    id: 'journalist',
    judul: 'AI Journalist Agent',
    deskripsi: 'Meneliti, menulis, dan mengedit artikel topik apapun.',
    kategori: 'Advanced',
    ikon: LucideIcons.messageSquareText,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/single_agent_apps/ai_journalist_agent/',
    promptStarter:
        'Tulis artikel berita tentang [topik] dengan pendekatan investigatif, termasuk latar belakang, argumentasi, dan kesimpulan.',
  ),
  IdeTemplate(
    id: 'consultant',
    judul: 'AI Consultant Agent',
    deskripsi:
        'Analisis pasar dan rekomendasi strategi dengan riset web langsung.',
    kategori: 'Advanced',
    ikon: LucideIcons.brain,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/single_agent_apps/ai_consultant_agent/',
    promptStarter:
        'Saya membuka bisnis [jenis] di [kota]. Berikan analisis pasar, target pelanggan, dan strategi pemasaran awal.',
  ),

  // ---------------------------------------------------------- Tim Multi-Agen
  IdeTemplate(
    id: 'competitor-intel',
    judul: 'AI Competitor Intelligence Agent Team',
    deskripsi: 'Stuktur teardown kompetitor dari situs mereka sendiri.',
    kategori: 'Tim Multi-Agen',
    ikon: LucideIcons.users,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/multi_agent_apps/agent_teams/ai_competitor_intelligence_agent_team/',
    promptStarter:
        'Analisis kompetitor [nama situs] dan buatkan laporan teardown: produk, harga, posisi pasar, dan kelemahan yang bisa dieksploitasi.',
  ),
  IdeTemplate(
    id: 'travel-planner-team',
    judul: 'AI Travel Planner Agent Team',
    deskripsi: 'Itinerari perjalanan lengkap yang disusun tim.',
    kategori: 'Tim Multi-Agen',
    ikon: LucideIcons.users,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/multi_agent_apps/agent_teams/ai_travel_planner_agent_team/',
    promptStarter:
        'Rencanakan liburan [jumlah hari] ke [tujuan] untuk [jumlah orang] dengan anggaran [X], termasuk transportasi, akomodasi, dan aktivitas harian.',
  ),
  IdeTemplate(
    id: 'llm-panel',
    judul: 'LLM Panel Agent Team',
    deskripsi:
        'Tiga vendor meninjau diff yang sama secara buta, lalu mendebatnya secara anonim.',
    kategori: 'Tim Multi-Agen',
    ikon: LucideIcons.users,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/multi_agent_apps/agent_teams/llm_panel_agent_team/',
    promptStarter:
        'Saya akan menyalin diff kode. Biarkan tiga model AI menilai secara buta, lalu diskusikan perbedaan pendapat mereka untuk saya.',
  ),

  // ---------------------------------------------------------------- Suara AI
  IdeTemplate(
    id: 'support-voice',
    judul: 'Customer Support Voice Agent',
    deskripsi: 'Jawaban suara didasarkan pada dokumen Anda sendiri.',
    kategori: 'Suara AI',
    ikon: LucideIcons.smartphone,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/voice_ai_agents/customer_support_voice_agent/',
    promptStarter:
        'Buatkan skrip agen suara untuk menangani keluhan pelanggan tentang [produk], dengan langkah escakasi dan FAQ.',
  ),
  IdeTemplate(
    id: 'voice-rag',
    judul: 'Voice RAG Agent (OpenAI SDK)',
    deskripsi: 'Tanyakan PDF Anda, dengarkan jawabannya.',
    kategori: 'Suara AI',
    ikon: LucideIcons.messageSquareText,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/voice_ai_agents/voice_rag_openaisdk/',
    promptStarter:
        'Saya akan mengunggah dokumen PDF. Buatkan sistem tanya-jawab suara yang menjawab berdasarkan isi dokumen.',
  ),

  // ---------------------------------------------------------- UI Generatif
  IdeTemplate(
    id: 'generative-ui',
    judul: 'Generative UI Starter Project',
    deskripsi:
        'Papan kanban yang dioperasikan chat yang Anda dan agen kerjakan bersama.',
    kategori: 'UI Generatif',
    ikon: LucideIcons.palette,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/generative_ui_agents/generative-ui-starter-project/',
    promptStarter:
        'Buatkan contoh kode antarmuka kanban yang bisa dioperasi melalui chat, dengan tugas yang ditambahkan oleh agen AI.',
  ),
  IdeTemplate(
    id: 'dashboard-canvas',
    judul: 'AI Dashboard Canvas Agent',
    deskripsi: 'Deskripsikan dashboard dalam chat, grafik muncul di kanvas langsung.',
    kategori: 'UI Generatif',
    ikon: LucideIcons.palette,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/generative_ui_agents/ai-dashboard-canvas-agent/',
    promptStarter:
        'Deskripsikan dashboard monitoring [topik] yang ingin saya buat, lalu agen akan merangkumnya sebagai grafik dan kertas kerja interaktif.',
  ),

  // ---------------------------------------------------------------- MCP
  IdeTemplate(
    id: 'github-mcp',
    judul: 'GitHub MCP Agent',
    deskripsi: 'Jelajahi dan analisis repo apapun dalam bahasa Inggris melalui MCP.',
    kategori: 'MCP',
    ikon: LucideIcons.plug,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/mcp_ai_agents/github_mcp_agent/',
    promptStarter:
        'Hubungkan agen ini ke repository GitHub saya dan biarkan menjawab pertanyaan tentang kode, issue, dan pull request.',
  ),
  IdeTemplate(
    id: 'browser-mcp',
    judul: 'Browser MCP Agent',
    deskripsi: 'Kendalikan browser nyata dengan bahasa alami melalui MCP.',
    kategori: 'MCP',
    ikon: LucideIcons.smartphone,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/mcp_ai_agents/browser_mcp_agent/',
    promptStarter:
        'Gunakan agen ini untuk menavigasi [situs web], mengisi formulir, dan mengambil informasi secara otomatis melalui browser.',
  ),

  // ---------------------------------------------------------------- RAG
  IdeTemplate(
    id: 'basic-rag',
    judul: 'Basic RAG Chain',
    deskripsi: 'Pipeline pengambilan informasi minimal, diterapkan pada riset farmasi.',
    kategori: 'RAG',
    ikon: LucideIcons.database,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/rag_chain/',
    promptStarter:
        'Saya akan memberikan beberapa dokumen. Buatkan sistem tanya-jawab yang menjawab berdasarkan dokumen dengan kutipan sumber.',
  ),
  IdeTemplate(
    id: 'autonomous-rag',
    judul: 'Autonomous RAG',
    deskripsi: 'GPT-4o menjawab dari PDF Anda, dengan fallback ke pencarian web.',
    kategori: 'RAG',
    ikon: LucideIcons.database,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/autonomous_rag/',
    promptStarter:
        'Buatkan sistem RAG otonom yang menjawab pertanyaan dari PDF saya, dan jika informasi tidak cukup, mencarinya di web.',
  ),
  IdeTemplate(
    id: 'local-rag',
    judul: 'Local RAG Agent',
    deskripsi: 'Llama 3.2 dan Qdrant, tidak butuh kunci API.',
    kategori: 'RAG',
    ikon: LucideIcons.code,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/local_rag_agent/',
    promptStarter:
        'Bantu saya menyiapkan RAG lokal sepenuhnya dengan model Llama 3.2 tanpa membutuhkan kunci API atau server cloud.',
  ),
  IdeTemplate(
    id: 'knowledge-graph-rag',
    judul: 'Knowledge Graph RAG with Citations',
    deskripsi: 'Jawaban multi-lompat dengan atribusi sumber yang dapat diverifikasi.',
    kategori: 'RAG',
    ikon: LucideIcons.database,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/knowledge_graph_rag_citations/',
    promptStarter:
        'Buatkan sistem RAG berbasis knowledge graph yang menjawab pertanyaan kompleks dengan menunjukkan relasi antar informasi dan sumbernya.',
  ),

  // -------------------------------------------------------- Chat dengan Data
  IdeTemplate(
    id: 'chat-pdf',
    judul: 'Chat with PDF',
    deskripsi: 'Klasik, dalam 30 baris Python.',
    kategori: 'Chat dengan Data',
    ikon: LucideIcons.fileCode,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/chat_with_X_tutorials/chat_with_pdf/',
    promptStarter:
        'Saya akan mengunggah file PDF. Tolong baca isinya dan jawab pertanyaan saya berdasarkan dokumen tersebut.',
  ),
  IdeTemplate(
    id: 'chat-youtube',
    judul: 'Chat with YouTube Videos',
    deskripsi: 'Tanyakan video melalui transkripnya.',
    kategori: 'Chat dengan Data',
    ikon: LucideIcons.smartphone,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/chat_with_X_tutorials/chat_with_youtube_videos/',
    promptStarter:
        'Berikan saya tautan video YouTube, lalu saya akan menanyakan pertanyaan tentang isi transkrip video.',
  ),
  IdeTemplate(
    id: 'chat-gmail',
    judul: 'Chat with Gmail',
    deskripsi: 'Tanyakan kotak masuk Anda.',
    kategori: 'Chat dengan Data',
    ikon: LucideIcons.mail,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/chat_with_X_tutorials/chat_with_gmail/',
    promptStarter:
        'Hubungkan agen ini ke Gmail saya agar saya bisa menanyakan pertanyaan tentang pesan dan janji temu dalam kotak masuk.',
  ),

  // ---------------------------------------------------------------- Memori
  IdeTemplate(
    id: 'llama3-stateful',
    judul: 'Llama3 Stateful Chat',
    deskripsi: 'Obrolan yang menyimpan sesi dengan Llama 3.',
    kategori: 'Memori',
    ikon: LucideIcons.brain,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/llm_apps_with_memory_tutorials/llama3_stateful_chat/',
    promptStarter:
        'Buatkan contoh aplikasi obrolan yang mengingat percakapan sebelumnya di sesi yang sama menggunakan Llama 3.',
  ),
  IdeTemplate(
    id: 'headroom',
    judul: 'Headroom Context Optimization',
    deskripsi:
        'Kurangi biaya API LLM sebesar 50–90% tanpa kehilangan kualitas.',
    kategori: 'Optimasi',
    ikon: LucideIcons.clock,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/llm_optimization_tools/headroom_context_optimization/',
    promptStarter:
        'Tolong optimalkan prompt panjang saya agar menggunakan lebih sedikit token tanpa mengubah arti atau kualitas jawaban.',
  ),

  // ---------------------------------------------------------------- Kursus
  IdeTemplate(
    id: 'google-adk',
    judul: 'Google ADK Crash Course',
    deskripsi:
        'Agen starter, output terstruktur, alat, memori, callback, plugin, dan pola multi-agen.',
    kategori: 'Kursus',
    ikon: LucideIcons.bookOpen,
    link:
        'https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/ai_agent_framework_crash_course/google_adk_crash_course/',
    promptStarter:
        'Ajar saya dasar-dasar Google ADK dengan contoh agen sederhana yang bisa memanggil alat dan mengingat konteks.',
  ),
];
