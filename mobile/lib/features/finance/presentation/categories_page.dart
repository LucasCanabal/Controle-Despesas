import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/presentation/categories_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _categoryNameDialog(context, title: 'Nova categoria');
    if (name == null || name.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref.read(categoriesNotifierProvider.notifier).create(name.trim());
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final name = await _categoryNameDialog(
      context,
      title: 'Editar categoria',
      initialName: category.name,
    );
    if (name == null || name.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(categoriesNotifierProvider.notifier)
          .updateCategory(
            Category(
              id: category.id,
              name: name.trim(),
              archived: category.archived,
            ),
          );
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivar categoria?'),
        content: Text(
          'A categoria "${category.name}" deixará de aparecer nas opções.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-archive-category'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(categoriesNotifierProvider.notifier).archive(category.id);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-category'),
        heroTag: 'add-category',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar as categorias.'),
              TextButton(
                onPressed: () =>
                    ref.read(categoriesNotifierProvider.notifier).refresh(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              key: Key('categories-empty'),
              child: Text('Nenhuma categoria cadastrada.'),
            );
          }
          return ListView(
            children: [
              for (final category in items)
                ListTile(
                  key: ValueKey('category-${category.id}'),
                  title: Text(category.name),
                  subtitle: category.archived
                      ? const Text('Arquivada')
                      : const Text('Ativa'),
                  onTap: () => _edit(context, ref, category),
                  trailing: category.archived
                      ? const Icon(Icons.archive_outlined)
                      : IconButton(
                          key: Key('archive-${category.id}'),
                          tooltip: 'Arquivar',
                          onPressed: () => _archive(context, ref, category),
                          icon: const Icon(Icons.archive_outlined),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<String?> _categoryNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final controller = TextEditingController(text: initialName);
  final formKey = GlobalKey<FormState>();
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('category-name'),
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nome'),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty || name.length > 100) {
                return 'Informe um nome de até 100 caracteres.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('save-category'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

void _showError(BuildContext context, Object error) {
  final apiException = error is ApiException
      ? error
      : error is DioException && error.error is ApiException
      ? error.error as ApiException
      : null;
  final message = apiException == null
      ? messageForCode('INTERNAL_ERROR')
      : messageForCode(apiException.code);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
