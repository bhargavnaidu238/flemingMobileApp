import 'package:flutter/material.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class ReviewsPage extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const ReviewsPage({required this.arguments, Key? key}) : super(key: key);

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  // Lists
  List<dynamic> allReviews = [];
  List<dynamic> filteredReviews = [];

  // Pagination State
  bool isLoadingInitial = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentOffset = 0;
  final int limit = 10;
  final ScrollController _scrollController = ScrollController();

  // Filter and Sort State
  int selectedFilterStar = 0;
  String selectedSortOrder = "High to Low";

  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialReviews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMore) {
        _fetchMoreReviews();
      }
    }
  }

  // Initial Fetch (Reset)
  Future<void> _fetchInitialReviews() async {
    setState(() {
      isLoadingInitial = true;
      currentOffset = 0;
      allReviews.clear();
    });

    await _fetchData();

    setState(() => isLoadingInitial = false);
  }

  // Load next page
  Future<void> _fetchMoreReviews() async {
    setState(() => isLoadingMore = true);
    await _fetchData();
    setState(() => isLoadingMore = false);
  }

  Future<void> _fetchData() async {
    try {
      final String hotelId = widget.arguments['hotel_id'].toString();

      // Note: ReviewApiService needs to be updated to accept offset/limit
      // For now, we simulate the offset. Ensure your ReviewApiService.fetchReviews
      // sends these params to your Java backend.
      final List<dynamic> data = await ReviewApiService.fetchReviews(
          hotelId,
          offset: currentOffset,
          limit: limit
      );

      if (data.length < limit) {
        hasMore = false;
      }

      setState(() {
        allReviews.addAll(data);
        currentOffset += data.length;
        _applyFiltersAndSort();
      });
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
    }
  }

  void _applyFiltersAndSort() {
    List<dynamic> temp = List.from(allReviews);

    if (selectedFilterStar != 0) {
      temp = temp.where((r) => (int.tryParse(r['rating'].toString()) ?? 0) == selectedFilterStar).toList();
    }

    temp.sort((a, b) {
      final int ratingA = int.tryParse(a['rating'].toString()) ?? 0;
      final int ratingB = int.tryParse(b['rating'].toString()) ?? 0;
      return selectedSortOrder == "High to Low" ? ratingB.compareTo(ratingA) : ratingA.compareTo(ratingB);
    });

    setState(() => filteredReviews = temp);
  }

  void _showWriteReviewSheet() {
    _selectedRating = 0;
    _commentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Write a Review", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setSheetState(() => _selectedRating = index + 1),
                    icon: Icon(index < _selectedRating ? Icons.star : Icons.star_border, color: Colors.orangeAccent, size: 36),
                  );
                }),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Share details of your stay...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submitReview(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("Submit Review", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= ERROR HANDLING LOGIC =================
  void _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a rating")));
      return;
    }

    final String hotelId = widget.arguments['hotel_id'].toString();
    final String userId = ApiService.getUserId() ?? '';

    // Logic for duplicate handling
    final dynamic response = await ReviewApiService.submitReviewWithResponse(
      hotelId: hotelId,
      userId: userId,
      rating: _selectedRating,
      comment: _commentController.text.trim(),
    );

    if (response == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review submitted successfully!")));
      _fetchInitialReviews(); // Reset and reload
    } else if (response == "duplicate") {
      _showErrorDialog("Already Reviewed", "You have already provided the review. Please delete the previous review in order to give new feedback.");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to submit review")));
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.green))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String hotelName = widget.arguments['hotel_name'] ?? 'Hotel Reviews';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FFEA),
      appBar: AppBar(
        title: Text("Reviews - $hotelName", maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          // Header Container (Filters)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Customer Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("${allReviews.length} reviews loaded", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showWriteReviewSheet,
                      icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                      label: const Text("Write Review", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [0, 5, 4, 3, 2, 1].map((star) {
                            final isSelected = selectedFilterStar == star;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(star == 0 ? "All" : "$star ★"),
                                selected: isSelected,
                                selectedColor: Colors.green[700],
                                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                                onSelected: (val) {
                                  setState(() {
                                    selectedFilterStar = star;
                                    _applyFiltersAndSort();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedSortOrder,
                      icon: const Icon(Icons.sort, size: 18),
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedSortOrder = val;
                            _applyFiltersAndSort();
                          });
                        }
                      },
                      items: ['High to Low', 'Low to High'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List Section
          Expanded(
            child: isLoadingInitial
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : filteredReviews.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _fetchInitialReviews,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: filteredReviews.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == filteredReviews.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  return _buildReviewCard(filteredReviews[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 80, color: Colors.green.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("No reviews found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final int ratingCount = int.tryParse(review['rating'].toString()) ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(review['user_name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(review['created_at']?.split(' ')[0] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(children: List.generate(5, (i) => Icon(i < ratingCount ? Icons.star : Icons.star_border, size: 16, color: Colors.orangeAccent))),
            const SizedBox(height: 10),
            Text(review['comment'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }
}