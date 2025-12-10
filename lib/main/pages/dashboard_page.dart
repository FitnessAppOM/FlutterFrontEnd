import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../widgets/news_carousel.dart';
import '../../screens/announcements_page.dart';
import '../../services/news_service.dart';
import '../../models/news_item.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<NewsItem> _news = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      final items = await NewsApi.fetchNews(limit: 10);
      if (!mounted) return;
      setState(() {
        _news = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openAnnouncements() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnnouncementsPage(items: _news)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _news.isEmpty
        ? [
            NewsSlide(
              title: "Stay tuned",
              subtitle: "Announcements will appear here.",
              tag: "News",
              color: const Color(0xFF6A5AE0),
              onTap: _openAnnouncements,
            ),
          ]
        : _news
            .map(
              (n) => NewsSlide(
                title: n.title,
                subtitle: n.subtitle,
                tag: n.tag,
                color: const Color(0xFF6A5AE0),
                onTap: _openAnnouncements,
              ),
            )
            .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: "Dashboard"),
          const SizedBox(height: 16),
          if (_loading)
            const CardContainer(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Center(
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else ...[
            if (_error != null)
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Could not load news", style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              NewsCarousel(slides: slides),
          ],
          const SizedBox(height: 20),
          const CardContainer(
            child: Text("Dashboard content here", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
