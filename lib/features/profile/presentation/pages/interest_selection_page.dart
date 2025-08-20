// lib/features/interests/presentation/pages/interest_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/interest_bloc.dart';
import '../../bloc/interest_event.dart';
import '../../bloc/interest_state.dart';
import '../../data/repositories/interest_mock_repository.dart';

class InterestSelectionPage extends StatelessWidget {
  const InterestSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          InterestBloc(repository: InterestMockRepository())
            ..add(LoadInterests()),
      child: Scaffold(
        appBar: AppBar(title: Text("Select Your Interests")),
        body: BlocBuilder<InterestBloc, InterestState>(
          builder: (context, state) {
            if (state is InterestLoading) {
              return Center(child: CircularProgressIndicator());
            } else if (state is InterestLoaded) {
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.interests.length,
                      itemBuilder: (context, index) {
                        final interest = state.interests[index];
                        return ListTile(
                          title: Text(interest.name),
                          trailing: Checkbox(
                            value: interest.isSelected,
                            onChanged: (_) {
                              context.read<InterestBloc>().add(
                                ToggleInterest(interest.id),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      context.read<InterestBloc>().add(SaveInterests());
                    },
                    child: Text("Continue"),
                  ),
                ],
              );
            } else if (state is InterestSaved) {
              return Center(child: Text("✅ Interests Saved Successfully!"));
            } else if (state is InterestError) {
              return Center(child: Text("❌ Error: ${state.message}"));
            }
            return Container();
          },
        ),
      ),
    );
  }
}
