import 'package:flutter/material.dart';

class SearchQueryField extends StatelessWidget {
  const SearchQueryField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
    required this.onSearch,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search scenic spots, cities, or attractions',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Search',
              onPressed: enabled ? onSearch : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }
}
